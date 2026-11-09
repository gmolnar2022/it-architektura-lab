# IT Architecture – 1. hét – eredeti feladatlap részletei

## 1. feladat – Belépés az Azure-ba

Nyisd meg az Azure Portalt, és jelentkezz be az egyetemi fiókoddal. Ha szükséges, aktiváld az [**Azure for Students**](https://azure.microsoft.com/free/students/){target="_blank"} előfizetést.


Az Azure-előfizetés azonosítója (Subscription ID)



## 2. feladat – Virtuális gép: Alapadatok

Nyisd meg a **Virtuális gépek (Virtual machines)** szolgáltatást, majd kezdd el egy új **Azure-beli virtuális gép (Azure virtual machine)** létrehozását. Az **Alapadatok (Basics)** lapon végezd el az alábbi beállításokat.


Erőforráscsoport (Resource group) – hozz létre egy új erőforráscsoportot


Virtuális gép neve (Virtual machine name) – adj meg egy tetszőleges nevet


Régió (Region) – válassz egy támogatott régiót



ⓘ Hogyan ellenőrizhetem, mely régiókat használhatom?

Az Azure for Students előfizetés korlátozhatja a használható Azure-régiókat. Ha a virtuális gép létrehozása régiókorlátozás miatt nem sikerül, az alábbi szkript segítségével ellenőrizheted az előfizetésedben használható régiókat.


Nyisd meg az Azure Cloud Shellt.
A Cloud Shell környezeteként válaszd a Bash lehetőséget.
Töltsd le az azure-region-check.sh fájlt.
A Cloud Shellben válaszd a Manage files → Upload lehetőséget, majd töltsd fel a letöltött fájlt.
Futtasd az alábbi két parancsot:


chmod +x azure-region-check.sh
./azure-region-check.sh

A régiók ellenőrzése néhány percet vehet igénybe. A futás végén keresd meg az ALLOWED REGIONS részt, és a virtuális gép létrehozásakor próbáld meg az ott felsorolt régiók valamelyikét.

Megjegyzés: Attól, hogy egy régió használata engedélyezett, még nem biztos, hogy az adott régióban minden virtuálisgép-méret és rendszerkép elérhető.



Rendelkezésre állási zóna (Availability zone): ne válassz rendelkezésre állási zónát.
Biztonság típusa (Security type): válaszd a Megbízható indítás (Trusted launch) lehetőséget.
Rendszerkép (Image): válassz az adott régióban elérhető, Microsoft által kiadott Windows kliens rendszerképet. Elsőként a Windows 11 Enterprise, version 25H2 rendszerképet keresd. Ha ez nem érhető el, választhatsz például Windows 11 Pro vagy Windows 10 Enterprise rendszerképet is. Ne válassz külső gyártó fizetős Marketplace-rendszerképét.
Méret (Size): elsőként válaszd a Standard_B2ls_v2 méretet.

::: {.callout-note title="Megjegyzés a gépmérethez"}
Előfordulhat, hogy a B sorozatú virtuális gép az adott régióban vagy előfizetéssel nem telepíthető. Ha a rendszer elutasítja a választott B sorozatú méretet, válassz egy elérhető **D sorozatú** gépet, például **Standard_D2s_v3** méretet.
:::

Felhasználónév (Username) – add meg a virtuális gép rendszergazdai felhasználónevét


Jelszó (Password): adj meg egy megfelelő jelszót, majd erősítsd meg az Azure Portalon. A jelszót a munkafüzetbe ne írd be!

Az oldal alján fogadd el a Windows használatához szükséges licencfeltételeket. A többi beállítást hagyd változtatás nélkül.


![Az Azure virtuális gép Alapadatok (Basics) beállításai](../../images/week01/vm-basics.png){width="90%"}

## 3. feladat – Virtuális gép: Lemezek

Nyisd meg a **Lemezek (Disks)** fület. Az **operációsrendszer-lemez típusánál (OS disk type)** válaszd a **Standard HDD** lehetőséget. Ez a gyakorlat céljára megfelelő és költségtakarékos választás.

**A többi beállítást hagyd változtatás nélkül.**


A beállítást elvégeztem
Igen


![A Standard HDD kiválasztása a Lemezek (Disks) lapon](../../images/week01/vm-disks.png){width="90%"}

## 4. feladat – Virtuális gép: Hálózatkezelés

Nyisd meg a **Hálózatkezelés (Networking)** fület. A gyakorlat során használhatod az Azure által automatikusan létrehozott hálózati beállításokat.

Mielőtt továbblépsz, győződj meg arról, hogy:

- a **Virtuális hálózat (Virtual network)** ki van töltve;
- az **Alhálózat (Subnet)** ki van töltve;
- a **Nyilvános IP-cím (Public IP)** létrehozása engedélyezett;
- az **RDP (3389)** bejövő port engedélyezett.

::: {.callout-note title="Miért kell az RDP-port?"}
A 3389-es RDP-port megnyitására azért van szükség, hogy a későbbi feladatban távolról kapcsolódni tudj a Windows virtuális géphez.
:::

**A többi beállítást hagyd változtatás nélkül.** A **Felügyelet (Management)**, **Monitorozás (Monitoring)** és **Speciális (Advanced)** füleken nem szükséges módosítanod semmit. Lépj tovább az **Áttekintés + létrehozás (Review + create)** fülre.


A hálózati beállításokat ellenőriztem
Igen


![A virtuális gép Hálózatkezelés (Networking) beállításai](../../images/week01/vm-networking.png){width="90%"}

## 5. feladat – Áttekintés, létrehozás és a telepítés ellenőrzése

Nyisd meg az **Áttekintés + létrehozás (Review + create)** oldalt. Várd meg a sikeres ellenőrzést, majd válaszd a **Létrehozás (Create)** gombot. Várd meg, amíg az Azure jelzi, hogy a virtuális gép telepítése sikeresen befejeződött, majd nyisd meg a létrehozott virtuális gép **Áttekintés (Overview)** oldalát.

Keresd meg és add meg az alábbi adatokat.


Nyilvános IP-cím (Public IP address)


Magánhálózati IP-cím (Private IP address)


Virtuális hálózat (Virtual network)



![A létrehozott virtuális gép Áttekintés (Overview) oldala](../../images/week01/vm-overview.png){width="90%"}

## 6. feladat – Csatlakozás a virtuális géphez RDP-vel

Mielőtt csatlakozol, a **tantermi gépen** nyiss meg egy PowerShell ablakot, és ellenőrizd, hogy elérhető-e a virtuális gép RDP-portja. A `` helyére az előző feladatban feljegyzett címet írd:

```powershell
Test-NetConnection  -Port 3389
```

A kapcsolat ellenőrzéséhez add meg azt a **PowerShell-parancsot**, amelyet a tantermi gépen futtattál. A parancsban a virtuális gép tényleges nyilvános IP-címe szerepeljen.


A kapcsolat teszteléséhez használt PowerShell-parancs

A `TcpTestSucceeded` sorban kapott érték




Ezután az Azure Portalon válaszd a **Csatlakozás (Connect) → RDP** lehetőséget, majd az **RDP-fájl letöltése (Download RDP File)** lehetőséget. Nyisd meg a letöltött `.rdp` fájlt.

![Az RDP-fájl letöltése a Csatlakozás (Connect) oldalon](../../images/week01/vm-rdp.png){width="90%"}

::: {.callout-warning title="Figyelem – Bejelentkezési adatok"}
A virtuális gépre **ne az egyetemi hálózati felhasználóneveddel és jelszavaddal** próbálj bejelentkezni. Az RDP-kapcsolathoz a virtuális gép létrehozásakor, az **Alapadatok (Basics)** lapon megadott **helyi rendszergazdai felhasználónevet és jelszót** használd. Ha a Windows másik fiókot ajánl fel, válaszd a **További lehetőségek (More choices) → Másik fiók használata (Use a different account)** lehetőséget.
:::

::: {.callout-note title="Első bejelentkezés"}
Az első bejelentkezéskor a Windows néhány kezdeti beállítással kapcsolatos kérdést jeleníthet meg, például az **adatvédelmi (Privacy)** beállításokról. Végezd el a szükséges kezdeti beállításokat, amíg meg nem jelenik a Windows asztal.
:::

## 7. feladat – Azure Cloud Shell

Indítsd el az **Azure Cloud Shellt**, és válaszd a **PowerShell** környezetet.

![Az Azure Cloud Shell megnyitása](../../images/week01/azure-cloud-shell.png){width="90%"}

Állítsd be aktív előfizetésként az **Azure for Students** előfizetést a `Set-AzContext` parancs segítségével.

::: {.callout-tip title="Tipp"}
Az előfizetés nevét idézőjelek között add meg.
:::


A használt PowerShell-parancs



## 8. feladat – Azure-előfizetések listázása

Listázd az elérhető Azure-előfizetéseidet, majd jelenítsd meg csak a `Name` és `State` tulajdonságokat.

::: {.callout-tip title="Tipp"}
A PowerShellben a visszakapott objektumok kiválasztott tulajdonságait a `Select-Object` paranccsal jeleníthetjük meg.
:::


Az előfizetések listázására használt parancs


Csak a Name és State tulajdonságok megjelenítése


A parancs eredménye



## 9. feladat – Resource Groupok lekérdezése

Listázd az előfizetésed Resource Groupjait Azure PowerShellből.


A használt parancs


A saját VM-ed Resource Groupjának neve



## 10. feladat – Virtuális gépek lekérdezése

Listázd az előfizetésed virtuális gépeit Azure PowerShellből.


A használt parancs


A saját virtuális géped neve



## 11. feladat – A virtuális gép állapota és vezérlése

Kérdezd le a VM állapotát. Ismerkedj meg a `Start-AzVM`, `Stop-AzVM` és `Restart-AzVM` parancsokkal.

::: {.callout-note title="Fontos"}
Ne állítsd le végleg a VM-et addig, amíg a következő feladatokhoz még szükséged van rá.
:::


Az állapot lekérdezésére használt parancs


A VM aktuális állapota



## 12. feladat – PowerShell script kiegészítése

Ebben a feladatban egy részben elkészített PowerShell scriptet fogsz használni. A script lekérdezi a virtuális gép aktuális állapotát és az operációsrendszer-lemez méretét. **A kódvázat másold be**, és csak a két hiányzó sort egészítsd ki.

::: {.callout-tip title="Script létrehozása a Cloud Shellben"}
A Cloud Shellben indítsd el a beépített szerkesztőt:

```powershell
code .
```

Hozz létre egy `vm-info.ps1` nevű fájlt, másold bele az alábbi kódvázat, egészítsd ki a két hiányzó sort, majd mentsd el. A scriptet ezután így futtathatod:

```powershell
./vm-info.ps1
```

A PowerShell-scriptek létrehozásával és futtatásával az előadáson is foglalkoztunk.
:::

```powershell
$resourceGroup = "SAJÁT ERŐFORRÁSCSOPORT"
$vmName = "SAJÁT VM NÉV"

# A virtuális gép állapotának lekérdezése
$vmStatus = __________________________________________

$powerState = ($vmStatus.Statuses |
    Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus

Write-Host "A virtuális gép állapota: $powerState"

# A virtuális gép és az OS-lemez adatainak lekérdezése
$vm = Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName
$diskName = $vm.StorageProfile.OsDisk.Name
$disk = Get-AzDisk -ResourceGroupName $resourceGroup -DiskName $diskName

# Az OS-lemez méretének kiírása
_____________________________________________________
```


1. hiányzó PowerShell-sor


2. hiányzó PowerShell-sor



## 13. feladat – Ismeretlenebb PowerShell-kód megértése AI segítségével

Az alábbi scriptben olyan PowerShell-elemek is szerepelnek, amelyekkel az előadáson még nem foglalkoztunk. Másold a kódot a Cloud Shellbe, futtasd le, majd használj generatív AI-eszközt a működésének megértéséhez.

```powershell
Get-AzVM -Status |
    Select-Object Name, ResourceGroupName,
        @{Name="PowerState"; Expression={
            ($_.Statuses | Where-Object {$_.Code -like "PowerState/*"}).DisplayStatus
        }} |
    Format-Table -AutoSize
```

Kérd meg az AI-t, hogy a script működését **PowerShellt még csak alapszinten ismerő hallgató számára** magyarázza el. Ezután a saját szavaiddal foglald össze, mit csinál a script, és mi a `Select-Object` szerepe.


Az AI-nak adott prompt


Saját összefoglalásod (2–4 mondat)



## 14. feladat – Automatikus leállítás beállítása és ellenőrzése

Nyisd meg a létrehozott virtuális gépet az Azure Portalon, és keresd meg az **Automatikus leállítás (Auto-shutdown)** beállítást.

- Engedélyezd az automatikus leállítást.
- Állítsd a leállítás időpontját minden nap **22:00**-ra.
- Az e-mailes értesítést **ne engedélyezd**.
- Mentsd a beállítást.

Ezután ellenőrizd PowerShellből, hogy az Azure létrehozta-e a megfelelő ütemezést. Egészítsd ki a következő parancsot a megfelelő **PowerShell-utasítás nevével**, és cseréld le a `SAJÁT ERŐFORRÁSCSOPORT` szöveget a saját erőforráscsoportod nevére.

```powershell
________________ `
    -ResourceGroupName "SAJÁT ERŐFORRÁSCSOPORT" `
    -ResourceType "Microsoft.DevTestLab/schedules" `
    -ExpandProperties |
    Select-Object -ExpandProperty Properties
```

Futtasd a kiegészített parancsot az **Azure Cloud Shell** PowerShell környezetében. A kimenetben keresd meg a `dailyRecurrence` és a `notificationSettings` mezőt.


A kiegészített és lefuttatott PowerShell-parancs


A `dailyRecurrence` mező teljes értéke


A `notificationSettings` mező teljes értéke



## 15. feladat – A virtuális gép leállítása és ellenőrzése

A gyakorlat végén állítsd le a virtuális gépet **PowerShell-paranccsal**, majd egy másik PowerShell-paranccsal ellenőrizd a gép állapotát. A leállítással elkerülheted, hogy a virtuális gép feleslegesen használja az Azure-kreditedet.


A leállításhoz használt PowerShell-parancs


Az állapot ellenőrzéséhez használt PowerShell-parancs


A VM végső állapota



