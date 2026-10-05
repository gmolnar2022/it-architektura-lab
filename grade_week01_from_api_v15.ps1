param(
    [Parameter(Mandatory=$true)][string]$ApiBaseUrl,
    [Parameter(Mandatory=$true)][string]$FunctionKey,
    [Parameter(Mandatory=$true)][Alias("StudentList")][string]$EmailCsv,
    [string]$OutputPath = ".\graded\week01_v15"
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
$dirCorrected = Join-Path $OutputPath "01_javitott"
$dirReview = Join-Path $OutputPath "02_atnezendo"
$dirPrevious = Join-Path $OutputPath "03_korabbi_beadasok"
$dirUnknown = Join-Path $OutputPath "04_ismeretlen_neptun"
$dirInvalid = Join-Path $OutputPath "05_ervenytelen_neptun"
$dirMissing = Join-Path $OutputPath "06_nincs_beadas"
$dirReports = Join-Path $OutputPath "00_osszesitok"
@($dirCorrected,$dirReview,$dirPrevious,$dirUnknown,$dirInvalid,$dirMissing,$dirReports) | ForEach-Object {
    New-Item -ItemType Directory -Force -Path $_ | Out-Null
}

function Read-StudentListCsv([string]$Path) {
    if (-not (Test-Path $Path)) { throw "Az email.csv nem talalhato: $Path" }

    $rows = @(Import-Csv -Path $Path -Encoding UTF8)
    if ($rows.Count -eq 0) { throw "Az email.csv ures." }

    $required = @("First name","Last name","Username","Email address")
    $headers = @($rows[0].PSObject.Properties.Name)
    foreach ($column in $required) {
        if ($headers -notcontains $column) {
            throw "Az email.csv fajlbol hianyzik a kovetkezo oszlop: $column"
        }
    }

    $map = @{}
    foreach ($row in $rows) {
        $code = ([string]$row.Username).Trim().ToUpper()
        if ($code -match '^[A-Z0-9]{6}$') {
            $firstName = ([string]$row.'First name').Trim()
            $lastName  = ([string]$row.'Last name').Trim()
            $fullName  = (($lastName + " " + $firstName).Trim())
            $email     = ([string]$row.'Email address').Trim()

            $map[$code] = [pscustomobject]@{
                Neptun = $code
                Name = $fullName
                FirstName = $firstName
                LastName = $lastName
                Email = $email
            }
        }
    }
    return $map
}

$studentMap = Read-StudentListCsv $EmailCsv
Write-Host ("Hivatalos hallgatoi lista: {0} fo." -f $studentMap.Count)

$uri = $ApiBaseUrl.TrimEnd('/') + "/api/submissions?week=1"
$headers = @{ "x-functions-key" = $FunctionKey }
Write-Host "Week 1 submissions letoltese..."
$api = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -TimeoutSec 120
if (-not $api.success) { throw "A submissions API sikertelen valaszt adott." }
Write-Host ("Blob beadasok: {0}" -f $api.count)

$invalidSubmissions = @()
$validItems = @()

foreach ($item in $api.submissions) {
    $submission = $item.submission
    $code = ([string]$submission.student_id).Trim().ToUpper()
    $reason = $null
    if ($code -notmatch '^[A-Z0-9]{6}$') {
        $reason = "Ervenytelen Neptun-formatum"
    }
    elseif (-not $studentMap.ContainsKey($code)) {
        $reason = "A Neptun-kod nincs a kurzus hivatalos nevsoraban"
    }

    if ($reason) {
        $invalidSubmissions += [pscustomobject]@{
            Neptun = $code
            Blob = [string]$item.blob_name
            SubmittedAt = [string]$submission.submitted_at
            Problema = $reason
            Submission = $submission
        }
    } else {
        $validItems += [pscustomobject]@{
            Neptun = $code
            Name = $studentMap[$code].Name
            Email = $studentMap[$code].Email
            BlobName = [string]$item.blob_name
            Submission = $submission
            SubmittedAt = [DateTimeOffset]::Parse([string]$submission.submitted_at)
        }
    }
}

# Only the latest valid submission per student is graded.
$selected = @()
$duplicateRows = @()
foreach ($grp in ($validItems | Group-Object Neptun)) {
    $ordered = @($grp.Group | Sort-Object SubmittedAt -Descending)
    $selected += $ordered[0]
    if ($ordered.Count -gt 1) {
        foreach ($old in ($ordered | Select-Object -Skip 1)) {
            $duplicateRows += [pscustomobject]@{
                Neptun = $old.Neptun
                Nev = $old.Name
                Email = $old.Email
                SubmittedAt = $old.Submission.submitted_at
                Blob = $old.BlobName
                Megjegyzes = "Korabbi beadas - nem kerult javitasra"
            }
        }
    }
}

$missingStudents = @()
foreach ($code in ($studentMap.Keys | Sort-Object)) {
    if (-not ($selected.Neptun -contains $code)) {
        $missingStudents += [pscustomobject]@{ Neptun=$code; Nev=$studentMap[$code].Name; Email=$studentMap[$code].Email }
    }
}

Write-Host ("Ervenyes egyedi hallgatok: {0}; korabbi ismetelt beadasok: {1}; ervenytelen/ismeretlen beadasok: {2}; beadas nelkuli hallgatok: {3}" -f `
    $selected.Count, $duplicateRows.Count, $invalidSubmissions.Count, $missingStudents.Count)

function ConvertTo-HtmlEncoded([object]$s) { [System.Net.WebUtility]::HtmlEncode([string]$s) }
function ConvertTo-Utf8Text([object]$Value) {
    if ($null -eq $Value) { return "" }
    $text = [string]$Value
    $win1252 = [System.Text.Encoding]::GetEncoding(1252)
    $utf8 = [System.Text.Encoding]::UTF8

    # Some submitted fields have been mojibaked more than once.
    # Repair repeatedly, but only while the number of typical corruption
    # markers decreases.
    for ($i = 0; $i -lt 3; $i++) {
        $before = ([regex]::Matches($text, '[ÃÂÅÄÆÐØÞ�]')).Count
        if ($before -eq 0) { break }
        try {
            $candidate = $utf8.GetString($win1252.GetBytes($text))
            $after = ([regex]::Matches($candidate, '[ÃÂÅÄÆÐØÞ�]')).Count
            if ($after -lt $before) { $text = $candidate } else { break }
        }
        catch { break }
    }
    # Final cleanup for a recurring backend mojibake pattern where Hungarian ő/Ő
    # has already become the Unicode replacement character before PowerShell sees it.
    # Typical words in the grading feedback: törő, mezőt, követő, stb.
    $text = $text -replace 'tör\?','törő'
    $text = $text -replace 'mez\?t','mezőt'
    $text = $text -replace 'mez\?','mező'
    $text = $text -replace 'Tör\?','Törő'
    $text = $text -replace 'Mez\?t','Mezőt'
    $text = $text -replace 'Mez\?','Mező'

    return $text
}
function NotBlank($v) { -not [string]::IsNullOrWhiteSpace([string]$v) }
function IsGuid($v) { [guid]::TryParse([string]$v, [ref]([guid]::Empty)) }
function IsIPv4($v) {
    $value = ([string]$v).Trim()
    $ip=$null
    [System.Net.IPAddress]::TryParse($value,[ref]$ip) -and
    $ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork
}
function IsPrivateIPv4($v) {
    $value = ([string]$v).Trim()
    if (-not (IsIPv4 $value)) { return $false }
    $o = $value.Split('.') | ForEach-Object { [int]$_ }
    ($o[0]-eq 10) -or ($o[0]-eq 172 -and $o[1]-ge 16 -and $o[1]-le 31) -or
    ($o[0]-eq 192 -and $o[1]-eq 168)
}
function IsPublicIPv4($v) {
    $value = ([string]$v).Trim()
    (IsIPv4 $value) -and -not (IsPrivateIPv4 $value)
}

function Format-Duration([double]$Seconds) {
    if ($Seconds -le 0) { return "n/a" }
    $ts = [TimeSpan]::FromSeconds([math]::Round($Seconds))
    if ($ts.TotalHours -ge 1) {
        return ("{0} ora {1} perc" -f [math]::Floor($ts.TotalHours), $ts.Minutes)
    }
    return ("{0} perc" -f [math]::Max(1, [math]::Round($ts.TotalMinutes)))
}

function Grade($j) {
    $a=$j.answers
    $g=[ordered]@{}
    function Put($q,$ok,$method="automatic",$feedback="",$forceReview=$false) {
        $g[$q]=[pscustomobject]@{
            points = $(if($ok){1}else{0})
            max_points = 1
            status = $(if($ok){"correct"}elseif($forceReview){"review"}else{"incorrect"})
            method = $method
            feedback = $feedback
        }
    }

    Put Q01 (IsGuid $a.Q01_SUBSCRIPTION_ID)
    Put Q02 ((NotBlank $a.Q02_RESOURCEGROUP) -and (NotBlank $a.Q02_VMNAME) -and
             (NotBlank $a.Q02_REGION) -and (NotBlank $a.Q02_USERNAME))
    Put Q03 ($a.Q03_DONE -eq "Igen")
    Put Q04 ($a.Q04_DONE -eq "Igen")
    $regionToken = (([string]$a.Q02_REGION).Trim().ToLower() -replace '[^a-z0-9]','')
    $vnetPattern = '^vnet-' + [regex]::Escape($regionToken) + '-1(?:/snet-' + [regex]::Escape($regionToken) + '-1)?$'
    Put Q05 ((IsPublicIPv4 $a.Q05_PUBLICIP) -and
             (IsPrivateIPv4 $a.Q05_PRIVATEIP) -and
             ($regionToken.Length -gt 0) -and
             (([string]$a.Q05_VNET).Trim().ToLower() -match $vnetPattern))
    Put Q06 ($a.Q06_COMMAND -match '\bTest-NetConnection\b' -and
             $a.Q06_COMMAND -match '-Port\s+3389\b' -and
             $a.Q06_COMMAND -match [regex]::Escape([string]$a.Q05_PUBLICIP) -and
             ([string]$a.Q06_TCP).ToLower() -eq "true")
    Put Q07 ($a.Q07_COMMAND -match '\bSet-AzContext\b' -and $a.Q07_COMMAND -match 'Azure\s+for\s+Students')
    $c08="$($a.Q08_COMMAND) $($a.Q08_FILTER)"
    Put Q08 ($c08 -match 'Get-AzSubscription' -and $c08 -match 'Select-Object' -and
             $c08 -match '\bName\b' -and $c08 -match '\bState\b')
    Put Q09 ($a.Q09_COMMAND -match '\bGet-AzResourceGroup\b')
    Put Q10 ($a.Q10_COMMAND -match '\bGet-AzVM\b')
    Put Q11 ($a.Q11_COMMAND -match '\bGet-AzVM\b' -and $a.Q11_COMMAND -match '-Status\b' -and (NotBlank $a.Q11_STATE))
    Put Q12 ($a.Q12_LINE1 -match '\bGet-AzVM\b' -and $a.Q12_LINE1 -match '-Status\b' -and
             $a.Q12_LINE2 -match '\bWrite-Host\b' -and $a.Q12_LINE2 -match 'DiskSizeGB')

    # Q13: blank answer is simply 0 points; only a submitted answer is sent to AI.
    if (-not (NotBlank $a.Q13_SUMMARY)) {
        Put Q13 $false "automatic" "Nincs kitoltve."
    }
    else {
        $aiEndpoint = $ApiBaseUrl.TrimEnd('/') + "/api/check"
        $aiBody = @{
            task_id = "Q13"
            task    = "A hallgato a sajat szavaival 2-4 mondatban foglalja ossze, mit csinal a megadott Get-AzVM -Status PowerShell script, es terjen ki a Select-Object szerepere is."
            answer  = [string]$a.Q13_SUMMARY
            prompt  = [string]$a.Q13_PROMPT
        } | ConvertTo-Json -Compress

        try {
            $aiResponse = Invoke-RestMethod -Uri $aiEndpoint -Method Post -ContentType "application/json; charset=utf-8" -Body $aiBody -TimeoutSec 60
            if ($aiResponse.success -eq $true -and $aiResponse.status -eq "pass") {
                $aiFeedback = ConvertTo-Utf8Text $aiResponse.feedback
                Put Q13 $true "ai" $aiFeedback
            }
            elseif ($aiResponse.success -eq $true -and $aiResponse.status -in @("needs_revision","invalid")) {
                $aiFeedback = ConvertTo-Utf8Text $aiResponse.feedback
                Put Q13 $false "ai" $aiFeedback
            }
            else {
                Put Q13 $false "ai_review" "Az AI valasza nem volt egyertelmuen feldolgozhato; oktatoi ellenorzes szukseges." $true
            }
        }
        catch {
            Put Q13 $false "ai_review" ("Az AI-ellenorzes nem volt elerheto; oktatoi ellenorzes szukseges. Technikai reszlet: " + $_.Exception.Message) $true
        }
    }

    $q14="$($a.Q14_COMMAND)"
    Put Q14 ($q14 -match '\bGet-AzResource\b' -and
             $q14 -match 'Microsoft\.DevTestLab/schedules' -and
             $q14 -match '-ExpandProperties\b' -and
             $q14 -match 'Select-Object\s+-ExpandProperty\s+Properties' -and
             ([string]$a.Q14_DAILYRECURRENCE -match '22:00|2200') -and
             ([string]$a.Q14_NOTIFICATIONSETTINGS -match 'status\s*=\s*Disabled'))

    Put Q15 ($a.Q15_STOPCOMMAND -match '\bStop-AzVM\b' -and
             $a.Q15_STATUSCOMMAND -match '\bGet-AzVM\b' -and
             $a.Q15_STATUSCOMMAND -match '-Status\b' -and
             ([string]$a.Q15_STATE).ToLower() -match 'deallocated|felszabad')

    return $g
}

$titles=@(
"","Belepes az Azure-ba","Virtualis gep: Alapadatok","Virtualis gep: Lemezek",
"Virtualis gep: Halozatkezeles","Telepites ellenorzese","RDP kapcsolat","Azure Cloud Shell",
"Azure-elofizetesek","Resource Groupok","Virtualis gepek","VM allapota es vezerlese",
"PowerShell script kiegeszitese","PowerShell-kod megertese AI segitsegevel",
"Automatikus leallitas","VM leallitasa es ellenorzese"
)
$fields=@{
1=@("Q01_SUBSCRIPTION_ID");2=@("Q02_RESOURCEGROUP","Q02_VMNAME","Q02_REGION","Q02_USERNAME")
3=@("Q03_DONE");4=@("Q04_DONE");5=@("Q05_PUBLICIP","Q05_PRIVATEIP","Q05_VNET")
6=@("Q06_COMMAND","Q06_TCP");7=@("Q07_COMMAND");8=@("Q08_COMMAND","Q08_FILTER","Q08_OUTPUT")
9=@("Q09_COMMAND","Q09_RESOURCEGROUP");10=@("Q10_COMMAND","Q10_VMNAME")
11=@("Q11_COMMAND","Q11_STATE");12=@("Q12_LINE1","Q12_LINE2")
13=@("Q13_PROMPT","Q13_SUMMARY");14=@("Q14_COMMAND","Q14_DAILYRECURRENCE","Q14_NOTIFICATIONSETTINGS")
15=@("Q15_STOPCOMMAND","Q15_STATUSCOMMAND","Q15_STATE")
}

$summary=@()
$review=@()

$gradeIndex = 0
$gradeTotal = $selected.Count
$selected | ForEach-Object {
    $gradeIndex++
    $selectedItem = $_
    $pctProgress = if ($gradeTotal -gt 0) { [math]::Round(($gradeIndex / $gradeTotal) * 100) } else { 100 }
    Write-Progress -Activity "Week 1 beadások javítása" -Status ("{0}/{1} - {2} - {3}%" -f $gradeIndex,$gradeTotal,$selectedItem.Neptun,$pctProgress) -PercentComplete $pctProgress
    Write-Host ("[{0}/{1}] {2} - {3}" -f $gradeIndex,$gradeTotal,$selectedItem.Neptun,$selectedItem.Name)

    $j = $selectedItem.Submission
    $studentName = $selectedItem.Name
    $studentEmail = $selectedItem.Email

    # Normalize mojibaked UTF-8 in every submitted answer before grading/rendering.
    if ($null -ne $j.answers) {
        foreach ($prop in @($j.answers.PSObject.Properties)) {
            if ($prop.Value -is [string]) {
                $prop.Value = ConvertTo-Utf8Text $prop.Value
            }
        }
    }
    $g=Grade $j
    $total=0; $reviewQs=@()
    foreach($q in 1..15){
        $k="Q{0:d2}" -f $q
        $total += $g[$k].points
        if($g[$k].status -eq "review"){
            $reviewQs += $k
            $reviewValues = @()
            foreach ($fieldName in $fields[$q]) {
                $fieldValue = $j.answers.PSObject.Properties[$fieldName].Value
                $reviewValues += ("{0} = {1}" -f $fieldName, $fieldValue)
            }
            $review += [pscustomobject]@{
                Neptun  = $j.student_id
                Feladat = $k
                Valasz  = ($reviewValues -join "`n")
            }
        }
    }

    # Header metadata from the submission JSON.
    $submittedDisplay = [string]$j.submitted_at
    try {
        $submittedDto = [DateTimeOffset]::Parse([string]$j.submitted_at)
        $submittedDisplay = $submittedDto.ToLocalTime().ToString("yyyy.MM.dd. HH:mm")
    } catch {}

    $activeSeconds = 0
    if ($null -ne $j.activity_summary -and $null -ne $j.activity_summary.sessions) {
        foreach ($session in $j.activity_summary.sessions) {
            if ($null -ne $session.active_seconds_estimate) {
                $activeSeconds += [double]$session.active_seconds_estimate
            }
        }
    }
    # Some schema variants may store sessions directly under activity.
    elseif ($null -ne $j.activity -and $null -ne $j.activity.sessions) {
        foreach ($session in $j.activity.sessions) {
            if ($null -ne $session.active_seconds_estimate) {
                $activeSeconds += [double]$session.active_seconds_estimate
            }
        }
    }
    $durationDisplay = Format-Duration $activeSeconds

    if ($reviewQs.Count -eq 0) {
        $gradingStatus = "Javitott"
        $statusClass = "status-ok"
    } else {
        $gradingStatus = "Atnezendo"
        $statusClass = "status-review"
    }

    # Save enriched JSON for audit/re-generation.
    $grading=[ordered]@{}
    foreach($q in 1..15){$k="Q{0:d2}" -f $q;$grading[$k]=$g[$k]}
    $grading["total_points"]=$total; $grading["max_points"]=15
    $j | Add-Member -Force NoteProperty grading ([pscustomobject]$grading)
    $studentOutputDir = if ($reviewQs.Count -eq 0) { $dirCorrected } else { $dirReview }
    $j | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 (Join-Path $studentOutputDir "$($j.student_id)_graded.json")

    $cards=""
    foreach($q in 1..15){
        $k="Q{0:d2}" -f $q; $gg=$g[$k]
        $answers=""
        foreach($f in $fields[$q]){
            $fieldValue = $j.answers.PSObject.Properties[$f].Value
            $fieldLabel = ConvertTo-HtmlEncoded $f
            $fieldValueSafe = ConvertTo-HtmlEncoded $fieldValue
            $answers += ("<div class='ans'><b>{0}</b><pre>{1}</pre></div>" -f $fieldLabel, $fieldValueSafe)
        }
        $cls = if($gg.status -eq "correct"){"ok"}elseif($gg.status -eq "review"){"review"}else{"incorrect"}
        $fb=if(NotBlank $gg.feedback){ConvertTo-HtmlEncoded $gg.feedback}else{
            if($gg.status -eq "correct"){"A valasz megfelel az automatikus ellenorzes kovetelmenyeinek."}
            elseif($gg.status -eq "review"){"Oktatoi ellenorzes szukseges."}
            else{"A valasz nem felel meg az automatikus ellenorzes kovetelmenyeinek, vagy nincs kitoltve."}
        }
        if ($gg.status -eq "correct") {
            $gradeLabel = "OK - Helyes"
        } elseif ($gg.status -eq "review") {
            $gradeLabel = "REVIEW - Ellenorizendo"
        } else {
            $gradeLabel = "0 PONT - Hibas vagy nincs kitoltve"
        }

        $titleSafe = ConvertTo-HtmlEncoded $titles[$q]
        $methodSafe = ConvertTo-HtmlEncoded $gg.method
        $cards += ("<section class='task {0}'><h2>{1}. feladat - {2} <span>{3}/1 pont</span></h2>{4}<div class='grade'><b>{5}</b> - {6}<p>{7}</p></div></section>" -f `
            $cls, $q, $titleSafe, $gg.points, $answers, $gradeLabel, $methodSafe, $fb)
    }

    $pct=[math]::Round(100*$total/15)
    $html=@"
<!doctype html><html lang="hu"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>ITARCH Week 1 - $($j.student_id)</title><style>
body{font-family:system-ui,Segoe UI,sans-serif;background:#f5f6f8;color:#1f2937;margin:0}
main{max-width:980px;margin:32px auto;padding:0 18px 50px}header,.task{background:#fff;border:1px solid #dfe3e8;border-radius:12px;padding:20px;margin:0 0 16px}
header h1{margin:0 0 8px}.summary{display:flex;gap:14px;flex-wrap:wrap;margin-top:16px}.box{background:#f1f4f7;padding:10px 15px;border-radius:9px}.box b{display:block;font-size:23px}.status-ok{font-size:18px!important}.status-review{font-size:18px!important}
.task{border-left:6px solid #2e7d32}.task.review{border-left-color:#b7791f}.task.incorrect{border-left-color:#b91c1c}.task h2{font-size:18px;margin:0 0 12px}.task h2 span{float:right}
pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f7f8fa;border:1px solid #e1e5ea;border-radius:7px;padding:9px}
.ans{margin:8px 0}.grade{background:#edf7ee;padding:11px;border-radius:8px;margin-top:12px}.review .grade{background:#fff7e6}.incorrect .grade{background:#fef2f2}.grade p{margin:6px 0 0}
@media print{body{background:#fff}main{max-width:none;margin:0}.task,header{break-inside:avoid}}
</style></head><body><main><header><h1>IT architektura - 1. het</h1><div>Javitott es pontozott feladatlap</div>
<div class="summary"><div class="box">Hallgato<b>$(ConvertTo-HtmlEncoded $studentName)</b></div><div class="box">Neptun<b>$(ConvertTo-HtmlEncoded $j.student_id)</b></div><div class="box">E-mail<b style="font-size:15px">$(ConvertTo-HtmlEncoded $studentEmail)</b></div><div class="box">Pontszam<b>$total/15</b></div><div class="box">Eredmeny<b>$pct%</b></div><div class="box">Leadas idopontja<b>$submittedDisplay</b></div><div class="box">Raforditott ido<b>$durationDisplay</b></div><div class="box">Statusz<b class="$statusClass">$gradingStatus</b></div></div></header>
$cards
</main></body></html>
"@
    Set-Content -Encoding UTF8 (Join-Path $studentOutputDir "ITARCH_week01_$($j.student_id)_javitott.html") $html

    $summary += [pscustomobject]@{
        Nev=$studentName; Neptun=$j.student_id; Email=$studentEmail; SubmittedAt=$j.submitted_at; Pont=$total; Maximum=15;
        Szazalek=$pct; Statusz=$gradingStatus; Ellenorizendo=($reviewQs -join ", ")
    }
}

Write-Progress -Activity "Week 1 beadások javítása" -Completed

$summary | Export-Csv (Join-Path $dirReports "week01_osszesites.csv") -NoTypeInformation -Encoding UTF8
$review | Export-Csv (Join-Path $dirReports "week01_ellenorizendo.csv") -NoTypeInformation -Encoding UTF8
$invalidSubmissions | Select-Object Neptun,Blob,SubmittedAt,Problema | Export-Csv (Join-Path $dirReports "week01_ervenytelen_es_ismeretlen_neptun.csv") -NoTypeInformation -Encoding UTF8
$duplicateRows | Export-Csv (Join-Path $dirReports "week01_ismetelt_beadasok.csv") -NoTypeInformation -Encoding UTF8
$missingStudents | Export-Csv (Join-Path $dirReports "week01_nincs_beadas.csv") -NoTypeInformation -Encoding UTF8

# Save exceptional original submissions into separate folders for easy manual inspection.
foreach ($bad in $invalidSubmissions) {
    $targetDir = if ($bad.Problema -eq "Ervenytelen Neptun-formatum") { $dirInvalid } else { $dirUnknown }
    $safeCode = if ([string]::IsNullOrWhiteSpace($bad.Neptun)) { "URES" } else { ($bad.Neptun -replace '[^A-Za-z0-9_-]','_') }
    $fn = "{0}_{1}.json" -f $safeCode, ([guid]::NewGuid().ToString("N").Substring(0,8))
    $bad.Submission | ConvertTo-Json -Depth 30 | Set-Content (Join-Path $targetDir $fn) -Encoding UTF8
}
foreach ($old in $duplicateRows) {
    # Metadata is sufficient here; the full older submission remains safely in Blob Storage.
    $old | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $dirPrevious ("{0}_{1}.json" -f $old.Neptun,([guid]::NewGuid().ToString("N").Substring(0,8)))) -Encoding UTF8
}
$missingStudents | Export-Csv (Join-Path $dirMissing "hallgatok_beadas_nelkul.csv") -NoTypeInformation -Encoding UTF8

$okCount = @($summary | Where-Object { $_.Statusz -eq "Javitott" }).Count
$reviewStudentCount = @($summary | Where-Object { $_.Statusz -eq "Atnezendo" }).Count
Write-Host ""
Write-Host "Kesz. Kimenet: $OutputPath"
Write-Host ("Javitott: {0}; Atnezendo: {1}; Korabbi beadas: {2}; Ismeretlen/ervenytelen: {3}; Nincs beadas: {4}" -f `
    $okCount,$reviewStudentCount,$duplicateRows.Count,$invalidSubmissions.Count,$missingStudents.Count)
