param(
    [Parameter(Mandatory=$true)][string]$EmailCsv,
    [Parameter(Mandatory=$true)][string]$CorrectedFolder,
    [switch]$Send,
    [string]$TestRecipient = ""
)

$ErrorActionPreference = "Stop"

function Read-Roster([string]$Path) {
    if (-not (Test-Path $Path)) { throw "Az email.csv nem talalhato: $Path" }
    $rows = @(Import-Csv -Path $Path -Encoding UTF8)
    if ($rows.Count -eq 0) { throw "Az email.csv ures." }

    $required = @("First name","Last name","Username","Email address")
    $headers = @($rows[0].PSObject.Properties.Name)
    foreach ($c in $required) {
        if ($headers -notcontains $c) { throw "Hianyzo CSV-oszlop: $c" }
    }

    $map = @{}
    foreach ($r in $rows) {
        $neptun = ([string]$r.Username).Trim().ToUpper()
        if ($neptun -match '^[A-Z0-9]{6}$') {
            $map[$neptun] = [pscustomobject]@{
                Neptun = $neptun
                FirstName = ([string]$r.'First name').Trim()
                LastName = ([string]$r.'Last name').Trim()
                Email = ([string]$r.'Email address').Trim()
            }
        }
    }
    return $map
}

if (-not (Test-Path $CorrectedFolder)) {
    throw "A 01_javitott mappa nem talalhato: $CorrectedFolder"
}

$roster = Read-Roster $EmailCsv
$files = @(Get-ChildItem -Path $CorrectedFolder -File -Filter "ITARCH_week01_*_javitott.html" | Sort-Object Name)

if ($files.Count -eq 0) {
    throw "Nem talaltam javitott HTML fajlt ebben a mappaban: $CorrectedFolder"
}

# Default: dry run. Actual sending requires explicit -Send.
if ($Send) {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        throw "Hianyzik a Microsoft Graph PowerShell SDK. Telepites: Install-Module Microsoft.Graph -Scope CurrentUser"
    }
    Import-Module Microsoft.Graph.Authentication
    Import-Module Microsoft.Graph.Users.Actions
    Connect-MgGraph -Scopes "Mail.Send" -NoWelcome
    $ctx = Get-MgContext
    if (-not $ctx.Account) { throw "Nem sikerult a Microsoft Graph bejelentkezes." }
    Write-Host ("Kuldo fiok: " + $ctx.Account) -ForegroundColor Cyan
}

$log = [System.Collections.Generic.List[object]]::new()
$i = 0

foreach ($file in $files) {
    $i++
    if ($file.Name -notmatch '^ITARCH_week01_([A-Z0-9]{6})_javitott\.html$') {
        Write-Warning "Nem felismerheto fajlnev, kihagyva: $($file.Name)"
        continue
    }

    $neptun = $Matches[1].ToUpper()
    if (-not $roster.ContainsKey($neptun)) {
        Write-Warning "Nincs a nevjegyzekben: $neptun - $($file.Name)"
        $log.Add([pscustomobject]@{Neptun=$neptun; IntendedEmail=""; ActualRecipient=""; File=$file.Name; Status="SKIPPED"; Detail="Nincs a CSV-ben"})
        continue
    }

    $student = $roster[$neptun]
    if ([string]::IsNullOrWhiteSpace($student.Email)) {
        Write-Warning "Nincs e-mail-cim: $neptun"
        $log.Add([pscustomobject]@{Neptun=$neptun; IntendedEmail=""; ActualRecipient=""; File=$file.Name; Status="SKIPPED"; Detail="Hianyzik az e-mail-cim"})
        continue
    }

    $recipient = if ([string]::IsNullOrWhiteSpace($TestRecipient)) { $student.Email } else { $TestRecipient.Trim() }
    $mode = if ($Send) { "KULDES" } else { "PROBA" }

    Write-Progress -Activity "Week 1 eredmenyek" -Status "[$i/$($files.Count)] $neptun -> $recipient ($mode)" -PercentComplete (($i/$files.Count)*100)
    Write-Host ("[{0}/{1}] {2} -> {3} [{4}]" -f $i,$files.Count,$neptun,$recipient,$mode)

    if (-not $Send) {
        $log.Add([pscustomobject]@{Neptun=$neptun; IntendedEmail=$student.Email; ActualRecipient=$recipient; File=$file.Name; Status="DRY-RUN"; Detail="Nem tortent kuldes"})
        continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $attachmentBase64 = [Convert]::ToBase64String($bytes)

    $testNote = ""
    if (-not [string]::IsNullOrWhiteSpace($TestRecipient)) {
        $testNote = "<p><strong>TESZT:</strong> Eredeti cimzett: $($student.Email)</p>"
    }

    $bodyHtml = @"
<p>Kedves $($student.FirstName)!</p>
<p>Csatoltan kuldom az IT architektura kurzus 1. heti feladatlapjanak javitott es pontozott valtozatat.</p>
$testNote
<p>Udvozlettel,<br>Oktato</p>
"@

    $params = @{
        message = @{
            subject = "IT architektura - 1. heti feladatlap eredmenye"
            body = @{
                contentType = "HTML"
                content = $bodyHtml
            }
            toRecipients = @(
                @{
                    emailAddress = @{
                        address = $recipient
                    }
                }
            )
            attachments = @(
                @{
                    "@odata.type" = "#microsoft.graph.fileAttachment"
                    name = $file.Name
                    contentType = "text/html"
                    contentBytes = $attachmentBase64
                }
            )
        }
        saveToSentItems = $true
    }

    try {
        Send-MgUserMail -UserId $ctx.Account -BodyParameter $params
        $log.Add([pscustomobject]@{Neptun=$neptun; IntendedEmail=$student.Email; ActualRecipient=$recipient; File=$file.Name; Status="SENT"; Detail=""})
    }
    catch {
        Write-Warning "Kuldesi hiba: $neptun - $($_.Exception.Message)"
        $log.Add([pscustomobject]@{Neptun=$neptun; IntendedEmail=$student.Email; ActualRecipient=$recipient; File=$file.Name; Status="ERROR"; Detail=$_.Exception.Message})
    }
}

Write-Progress -Activity "Week 1 eredmenyek" -Completed
$logPath = Join-Path $CorrectedFolder ("email_send_log_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".csv")
$log | Export-Csv -Path $logPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host ("Fajlok: " + $files.Count)
Write-Host ("Napló: " + $logPath)
if (-not $Send) {
    Write-Host "PROBAUZEM: egyetlen e-mail sem lett elkuldve." -ForegroundColor Yellow
    Write-Host "Valodi kuldeshez add meg a -Send kapcsolot." -ForegroundColor Yellow
}
elseif (-not [string]::IsNullOrWhiteSpace($TestRecipient)) {
    Write-Host ("TESZTKULDES: minden level a(z) " + $TestRecipient + " cimre ment.") -ForegroundColor Yellow
}
