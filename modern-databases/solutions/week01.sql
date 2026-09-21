/****** Script for SelectTopNRows command from SSMS  ******/
-- 1-5 ISMÉTLŐ FELADATOK
--1
/*
Melyek azok a termékek, amelyek neve az átlagosnál hosszabb?
Csak a termékek kódja és megnevezése jelenjen meg!
*/
SELECT TERMEKKOD, MEGNEVEZES
FROM Termek
WHERE LEN(MEGNEVEZES) >
(
 SELECT AVG(LEN(MEGNEVEZES))
 FROM Termek
)

--2
/*
Melyek azok a termékek, amelyekből ugyanannyi van készleten, mint dvd-ből?
Csak a termékek kódja és megnevezése jelenjen meg!
A Dvd ne szerepeljen a listában!

*/
SELECT TERMEKKOD, MEGNEVEZES
FROM Termek
WHERE MEGNEVEZES<>'Dvd' AND KESZLET =
(
  SELECT KESZLET	
  FROM Termek
  WHERE MEGNEVEZES='Dvd'
)

--3
/*
Melyek azok a raktárak, amelyekben nincs olyan termék, amelynek nevében a 
matrica szó benne van? A listában a raktárak minden adata jelenjen meg!
*/
SELECT *
FROM Raktar
WHERE RAKTAR_KOD NOT IN
(
  SELECT RAKTAR_KOD
  FROM Termek
  WHERE MEGNEVEZES LIKE '%matrica%'
)

--4
/*
Mely nap(ok)on történt a legkevesebb megrendelés?
 */
 SELECT REND_DATUM
 FROM Rendeles
 GROUP BY REND_DATUM
 HAVING COUNT(*)<= ALL
 (
   SELECT COUNT(*)
   FROM Rendeles
   GROUP BY REND_DATUM
 )
 --5
/*
  Listázzuk azon termékek adatait, amelyek listaára saját raktárukban
  a legkisebb!
*/
SELECT t.*
FROM Termek t
WHERE T.LISTAAR=
(
 SELECT MIN(t2.LISTAAR)
 FROM Termek t2
 WHERE t2.RAKTAR_KOD = t.RAKTAR_KOD
)

--6-10 Kötelező feladatok
--6
/*
 Készítsünk listát arról, hogy ügyfelenként (LOGIN), azon belül
 szállítási módonként hány megrendelés történt! 
 A lista tartalmazza a részösszegeket és a végösszeget is!
 Használjuk a ROLLUP záradékot!
 
*/
 SELECT [LOGIN], 
        SZALL_MOD AS 'Szállítási mód',
        COUNT(*) AS 'DB'
 FROM Rendeles
 GROUP BY ROLLUP([LOGIN], SZALL_MOD)

--7
/*
 Készítsünk listát a termékek számáról a következő csoportosítási
 szempontok szerint: kategória azonosító, raktárkód, raktárkód+mennyiségi 
 egység! A listát szűrjük azokra a csoportokra, ahol a termékek száma
 legalább 6!
 
*/
SELECT KAT_ID, RAKTAR_KOD, MEGYS, COUNT(*) AS 'DB'
FROM Termek
GROUP BY GROUPING SETS((KAT_ID),(RAKTAR_KOD),(RAKTAR_KOD, MEGYS))
HAVING COUNT(*)>=6
--8
/*
 Készítsünk listát az egyes termékkategóriákban lévő termékek számáról!
 Elég megjeleníteni a kategóriák azonosítóit és a darabszámokat!
 A lista megfelelően jelölve tartalmazza a végösszeget is!
 Az oszlopokat nevezzük el értelemszerűen! A listát rendezzük a darabszám
 szerint növekvő sorrendbe!
*/
 SELECT IIF(GROUPING(KAT_ID)=1, 'Összesen', CAST(KAT_ID AS nvarchar(4)))
        AS 'Kategória azonosító', 
        COUNT(*) AS 'DB'
 FROM Termek
 GROUP BY ROLLUP(KAT_ID)
 ORDER BY DB
 
--9
/*
 Készítsünk listát az ügyfelek számáról születési év szerint, azon belül
 nem szerinti bontásban! A lista megfelelően jelölve tartalmazza a 
 részösszegeket és a végösszeget is! Az oszlopoknak adjunk nevet értelemszerűen!
*/

SELECT IIF(GROUPING(SZULEV)=1, 'Összesen',CAST(SZULEV AS nvarchar(4))) 
       AS 'Születési év',
       CASE GROUPING_ID(SZULEV, NEM) 
	        WHEN 0 THEN NEM
			WHEN 1 THEN '**Nemek összesen**'
			WHEN 3 THEN 'Összesen'
       END AS 'Nem',
	   COUNT(*) AS 'DB'
FROM Ugyfel
GROUP BY ROLLUP(SZULEV, NEM)

--10
/*
Készítsünk listát a termékek számáról a felvitel hónapja, azon belül napja
szerint csoportosítva. A lista csak a részösszegeket és a végösszeget
tartalmazza! Az oszlopoknak adjunk megfelelő nevet!
Ötlet: HAVING + GROUPING_ID fv együttes használata
*/
SELECT MONTH(FELVITEL) AS 'Felvitel hónapja',
       DAY(FELVITEL) AS 'Felvitel napja',
	   COUNT(*) AS 'Darabszám'
FROM Termek
GROUP BY ROLLUP(MONTH(FELVITEL), DAY(FELVITEL))
HAVING GROUPING_ID(MONTH(FELVITEL),DAY(FELVITEL)) IN (1,3)


--11-15 Ajánlott feladatok

--11
/*
 Készítsünk listát éves bontásban norbert2 azonosítójú ügyfél
 rendeléseinek értékéről! A lista megfelelően jelölve tartalmazza
 a végösszeget is! Az oszlopokat nevezzük el
 értelemszerűen!

*/
 SELECT IIF(GROUPING(YEAR(REND_DATUM))=1,'Összesen',
            CAST(YEAR(REND_DATUM) AS nvarchar(4))) AS 'Év',
        SUM(rt.MENNYISEG*rt.EGYSEGAR) AS 'Érték'
 FROM Rendeles r JOIN Rendeles_tetel rt ON r.SORSZAM = Rt.SORSZAM
 WHERE r.[LOGIN]='norbert2'
 GROUP BY ROLLUP(YEAR(REND_DATUM))


--12
/*
Készítsünk listát szállítási dátumonként, azon belül szállítási módonkénkt
az egyes rendelések összmennyiségéről!
Csak azokat a termékeket vegyük figyelembe, amelyek mennyiségi egysége db!
A listát szűrjük úgy, hogy az csak a részösszeg sorokat és a végösszeget tartalmazza!

*/

SELECT r.SZALL_DATUM, r.SZALL_MOD, SUM(rt.MENNYISEG) AS 'Összmennyiség'
FROM Rendeles_tetel rt JOIN Termek t ON rt.TERMEKKOD = t.TERMEKKOD
     JOIN Rendeles r ON r.SORSZAM = rt.SORSZAM
WHERE t.MEGYS='db'
GROUP BY ROLLUP(r.SZALL_DATUM, r.SZALL_MOD)
HAVING GROUPING_ID(r.SZALL_DATUM, r.SZALL_MOD) IN (1,3)

--13
/*
 Készítsünk listát a termékek átlagos listaárairól!
 A lista legyen csoportosítva a következő szempontok alapján:
 kategórianév, kategórianév + raktárnév
 A lista tartalmazzon végösszeget (az átlagos árat minden termékre) is!
 Az átlagos értéke max. két tizedesjeggyel legyen megjelenítve!
*/
SELECT tk.KAT_NEV, r.RAKTAR_NEV, ROUND(AVG(LISTAAR),2) AS 'Átlagos ár'
FROM Termek t JOIN Raktar r ON t.RAKTAR_KOD = r.RAKTAR_KOD
              JOIN Termekkategoria tk on t.KAT_ID = tk.KAT_ID
GROUP BY GROUPING SETS((tk.KAT_NEV),(tk.KAT_NEV, r.RAKTAR_NEV),())
--GROUP BY ROLLUP(tk.KAT_NEV, R.RAKTAR_NEV)

--14
/*
Hány olyan ügyfél van, aki még nem rendelt semmit?
Csoportosítsuk őket nem szerint, azon belül életkor szerint!
A lista tartalmazza a részösszegeket és a végösszeget is!
*/
SELECT NEM, 
       YEAR(GETDATE())-SZULEV AS 'Életkor',
	   COUNT(*) AS 'Létszám'
FROM Ugyfel
WHERE [LOGIN] NOT IN
(
 SELECT [LOGIN]
 FROM Rendeles
)
GROUP BY ROLLUP(NEM, YEAR(GETDATE())-SZULEV)
--15
/*
Készítsünk listát arról, hogy évente hányszor rendelték meg
azokat a termékeket, amelyek kategóriájukban a legdrágábbak!
A lista jelenítse meg az évet, a termék nevét és a rendelés számát!
Jelenjenek meg a részösszegek és a végösszeg is!
*/
SELECT YEAR(r.rend_datum) AS 'Év',
       t.MEGNEVEZES AS 'Termék',
	   COUNT(*) AS 'DB'
FROM Rendeles_tetel rt JOIN Termek t ON rt.TERMEKKOD = t.TERMEKKOD
                       JOIN Rendeles r on r.SORSZAM =rt.SORSZAM
WHERE t.LISTAAR =
(
  SELECT MAX(LISTAAR)
  FROM Termek t2
  WHERE t.KAT_ID = t2.KAT_ID
)
GROUP BY ROLLUP(YEAR(r.rend_datum), t.MEGNEVEZES)



