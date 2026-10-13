# MES PEURS SUR LE PROJET (APJ) — et les réponses

> Légende : ✅ vérifié dans le dump/code que j'ai analysé · ⚠ à confirmer sur ton projet
> Case à cocher quand la peur n'est plus une peur.
> Règle pour TOUTES les peurs (y compris futures) : chaque bout de code cité a son
> **fichier + lignes** dans un bloc `### Sources` en fin de peur.

---

# [ ] PEUR n°1 — « Comment créer une nouvelle page reliée au dashboard ? »

**En clair :** il faut 2 choses : le fichier JSP **et** une ligne de menu en base. L'un sans l'autre = page invisible ou 404.

## Étape 1 — Créer la page
- Fichier : `arbiochem-war/web/pages/<module>/ma-page.jsp`
- Le plus simple : copier une page existante du même type (liste / saisie / fiche) et l'adapter.
- Une page ne s'ouvre jamais directement : elle passe par
  `module.jsp?but=<module>/ma-page.jsp`
  (`module.jsp` = le cadre commun : menu, en-tête ; il inclut ta page).

## Étape 2 — Ajouter l'entrée de menu (en base, pas dans le code)
- Table ✅ `MENUDYNAMIQUE` : `ID, LIBELLE, ICONE, HREF, RANG, NIVEAU, ID_PERE`
- Séquence ✅ `SEQ_MENUDYNAMIQUE`
- `HREF` = `module.jsp?but=<module>/ma-page.jsp` (même forme que les liens existants)
- `ID_PERE` = menu parent · `NIVEAU` = niveau d'imbrication · `RANG` = ordre d'affichage
- Astuce : copier les valeurs d'une ligne voisine :
  ```sql
  SELECT * FROM MENUDYNAMIQUE ORDER BY ID_PERE, RANG;
  ```

## Étape 3 — Donner le droit
- Table ✅ `USERMENU` : lier le menu à ton utilisateur / rôle. Sans ça, le menu existe mais tu ne le vois pas.
- Si la page enregistre/valide : droits d'actions dans ✅ `ACTIONROLE` ⚠.

## Étape 4 — Voir le résultat
- Une JSP ne demande **pas** de recompiler.
- Le menu est lu **à la connexion** ⚠ → déconnexion / reconnexion.
- Explique probablement les pages du dashboard qui s'ouvraient en 404 dans le mini-projet : pages et droits absents.

## Vérifier avant d'insérer
```sql
SELECT * FROM MENUDYNAMIQUE WHERE HREF LIKE '%bondecommande%';
SELECT * FROM USERMENU WHERE ROWNUM <= 5;
```
→ colle-moi le résultat et je te donne l'INSERT exact.

⚠ Je n'ai pas vu le code qui lit ces tables : l'ordre exact reste à confirmer sur ton projet.

### Sources — peur n°1 (fichier + lignes)
- `arbiochem-war/web/pages/module.jsp` : cadre commun qui inclut `?but=<page>` (vérifie l'include de `but` dans ce fichier).
- `arbiochem-war/web/pages/bondecommande/bondecommande-arbiochem-liste.jsp` l. 48, 70, 106 : exemple `setNomTable("As_BonDeCommande_MERETRAITE")` + `new PageRecherche(...)` + `pr.setApres(...)`.
- `arbiochem-war/web/pages/bondecommande/bondecommande-arbiochem-fiche.jsp` l. 44-45, 54, 60-64 : exemple `setNomTable("AS_BONDECOMMANDE_MERETRAITE")` + `new PageConsulte(f, request, u)` + `pc.getBase()`.
- Tables citées : `MENUDYNAMIQUE`, `USERMENU`, `ACTIONROLE` = noms lus dans ton dump SQL (pas de `.java`/`.jsp` pour elles dans ce projet).

---

# [ ] PEUR n°2 — « Comment ajouter un CHAMP, et un champ avec AUTOCOMPLÉTION (la loupe) ? »

**En clair :** un champ = la même info écrite à **3 endroits** (classe → JSP → liste/fiche ; **jamais le SQL**). L'autocomplétion = un champ ordinaire + **une ligne** dans la JSP qui dit « interroge telle classe ».

## A. Champ simple (texte, nombre, date)

> ⛔ **RÈGLE : on ne touche JAMAIS au script SQL / à la base.** Tout se fait côté **framework** (classe Java + JSP).
> Donc on n'écrit **pas** de `ALTER TABLE` et on ne modifie pas les vues. On travaille avec les colonnes qui **existent déjà**.

| # | Où | Quoi |
|---|---|---|
| 1 | Classe Java (ex. `As_BonDeCommande`) | attribut `monChamp` + `getMonChamp()` / `setMonChamp()` (APJ remplit par **nom** : colonne = attribut). C'est ce qui « fait apparaître » le champ. |
| 2 | `*-saisie.jsp` | le champ apparaît seul dans le formulaire ; on règle juste son aspect : `pi.getFormu().getChamp("monChamp").setLibelle("Mon champ");` |
| 3 | `*-liste.jsp` / `*-fiche.jsp` | `libEntete` + `libEnteteAffiche` (même ordre) pour la colonne ; `listeCrt` pour le filtre. Le nom doit exister dans la **classe / vue déjà utilisée** (`setNomTable(...)`). |

- Si un champ est demandé mais qu'**aucune colonne ne correspond** → ce n'est pas à moi de créer la colonne : le dire à Mr Tahina (« il manque la colonne X »).
- Pour **réutiliser une vue/classe existante** qui a déjà la colonne : `objet.setNomTable("NOM_VUE_EXISTANTE")` ✅ (vu dans `liste.jsp` l. 44).

Retirer un champ de l'écran : `getChamp("x").setVisible(false);` ✅ (vu pour `etat`).
Valeur par défaut : `.setDefaut("...")` ✅. Code JS / readonly : `.setAutre("readonly")` ou `.setAutre("onchange='maFonction()'")` ✅.

## B. Liste déroulante (pas de loupe)
Dans la saisie ✅ (l. 59-72) :
```java
Liste[] liste = new Liste[1];
liste[0] = new Liste("modepaiement", new TypeObjet("MODEPAIEMENT"), "val", "id");
pi.getFormu().changerEnChamp(liste);
```
= champ `modepaiement` ← table de nomenclature, affiche `val`, enregistre `id`.

## C. Champ AUTOCOMPLÉTION (la loupe) ✅ lu dans `bondecommande-arbiochem-saisie.jsp`
**Champ de l'en-tête (fournisseur), l. 86-87 :**
```java
pi.getFormu().getChamp("fournisseur")
  .setPageAppelCompleteAWhere("faturefournisseur.Fournisseur","id","Fournisseur","taxe","taxe"," and estActif = 1");
pi.getFormu().getChamp("fournisseur")
  .setPageAppelInsert("fournisseur/fournisseur-saisie.jsp","fournisseur;fournisseurlibelle","id;nom");
```
- `setPageAppelComplete…` = **la loupe** : quelle classe interroger (`faturefournisseur.Fournisseur`), quelle colonne = valeur enregistrée (`id`), quelle table, quelles colonnes recopier ailleurs.
- `…AWhere` = idem + **filtre SQL** (` and estActif = 1` → fournisseurs inactifs invisibles ; c'est une cause du « Fournisseur manquant »).
- `setPageAppelInsert` = le petit **« + »** : ouvre la page de création (`fournisseur-saisie.jsp`) pour créer l'élément à la volée.

**Champ d'une ligne (produit), l. 104-105 :**
```java
affichage.Champ.setPageAppelComplete(pi.getFormufle().getChampFille("produit"),
   "produits.IngredientsLib","id","AS_INGREDIENTS_LIB_ACHAT",
   "pu;taux;compte_achat;compte_achat;libelle",   // colonnes de la vue à récupérer
   "pu;tauxDeChange;compte;comptelibelle;produitLib"); // champs de la ligne à remplir avec
```
→ choisir un produit **remplit aussi** le PU, le taux, le compte… (colonne 1 → champ 1, etc., mêmes positions).

**Ce qui tourne derrière :** le JS de la page appelle la servlet `Deroulante` (✅ dans `apj-core2.jar`) → `CGenUtil.rechercher` sur la classe donnée → liste de suggestions. Les lignes 301-350 du JSP = déclenchement par Tab ou loupe (code JS spécifique BC, pas obligatoire pour un champ normal).

## D. Ajouter UN NOUVEAU champ avec loupe — recette
1. Faire A (1→3) : getter/setter dans la classe (la colonne existe déjà ; **pas de SQL**).
2. Choisir la **classe + vue** à interroger (ex. `Fournisseur`, `Lot`, `Parquet`). Elle doit avoir `id` + un libellé et être **recherchable** (sa table/vue existe).
3. Dans `*-saisie.jsp` après la création de `pi` :
   `pi.getFormu().getChamp("monChamp").setPageAppelComplete("package.Classe","id","TABLE_OU_VUE","colonneARecopier","champCible");`
   (copie la ligne du fournisseur, change les noms.)
4. Facultatif : `setPageAppelInsert(...)` pour le « + ».
5. Facultatif : filtre → variante `AWhere`.

**Test :** taper dans le champ → Tab ou loupe → **cliquer une suggestion** (sinon l'id réel n'est pas posé → erreur « manquant »).

## Pièges
- Champ visible mais vide en liste → la classe/vue utilisée (`setNomTable`) n'a pas cette colonne ; choisir une classe/vue existante qui l'a (pas de modification SQL).
- Autocomplete sans résultat → classe/table mal orthographiée ou `AWhere` trop strict ; regarder `server.log`.
- Champ de ligne : suffixe `_0`, `_1`… (`produit_0`) ; pour tous : `getChampFille("produit")` / `getChampMulitple("x")` ✅.
- Ordre des colonnes recopiées : positions alignées entre les deux listes `;`.

⚠ Non vu : le détail interne de `Deroulante` / `PageInsertMultiple` (dans les JAR) ; la syntaxe est celle du code existant ✅.

### Sources — peur n°2 (fichier + lignes)
Fichier principal : `arbiochem-war/web/pages/bondecommande/bondecommande-arbiochem-saisie.jsp`
- Listes déroulantes : l. 71-75 (`idDevise`), l. 78-80 (`modepaiement`), l. 82-88 (`idMagasin` + `setApresW`), l. 90-92 (`service`), l. 95 (`changerEnChamp`).
- Loupe en-tête fournisseur : l. 114-122 (`setPageAppelCompleteAWhere`) + l. 126-131 (`setPageAppelInsert`).
- Loupe ligne produit : l. 170-177 (`Champ.setPageAppelComplete` : vue `AS_INGREDIENTS_LIB_ACHAT` → champs `pu;tauxDeChange;compte;comptelibelle;produitLib`) + l. 180-184 (`setPageAppelInsert`).
- Champs cachés / libellés : l. 104 (`etat` → `setVisible(false)`), l. 133-139, l. 200-205 (`getChampMulitple(...).setVisible(false)`).
- Champs lignes `_0` : l. 192-199 + boucle l. 231-240 (`quantite_"+i`, `tva_"+i`, `idDevise_"+i`, `tauxDeChange_"+i`).
- Classe : `arbiochem-ejb/src/java/faturefournisseur/As_BonDeCommande.java` l. 31-68 (attributs), l. 121-125 (constructeur `setNomTable`), l. 186-189 (`setFournisseur` → `throw "Fournisseur manquant"`).

---

# [ ] PEUR n°3 — « Comment faire une INSERTION MULTIPLE (mère + plusieurs lignes) et afficher la SOMME en haut ? »

**En clair (✅ tout lu dans `bondecommande-arbiochem-saisie.jsp`) :** une insertion multiple = **1 mère** (le bon) + **N lignes filles** (les produits) dans **une seule page**, enregistrées en un clic. La somme = **du JavaScript** de la page, pas de Java.

## (1) L'insertion multiple — 5 morceaux

### ① Créer la mère, la fille et la page (l. 50-55)
```java
As_BonDeCommande mere = new As_BonDeCommande();
As_BonDeCommande_Fille fille = new As_BonDeCommande_Fille();
fille.setNomTable("AS_BONDECOMMANDE_FILLE_CPL");   // vue/table lue pour les lignes
int nombreLigne = 10;                              // nb de lignes affichées
PageInsertMultiple pi = new PageInsertMultiple(mere, fille, request, nombreLigne, u);
pi.setLien((String) session.getValue("lien"));
```
→ `PageInsertMultiple` fabrique **deux formulaires** : `pi.getFormu()` (mère) et `pi.getFormufle()` (lignes).

### ② Régler les champs de la mère (l. 75-90) → voir peur n°2
`pi.getFormu().getChamp("x").setLibelle(...)`, `setVisible(false)`, `setDefaut(...)`, `changerEnChamp(liste)`…

### ③ Régler les champs des lignes (l. 104-142)
```java
// ordre des colonnes du tableau (l. 176)
pi.getFormufle().setColOrdre(new String[]{"produit","produitLib","quantite","pu","tva","remise","tauxDeChange"});

// un champ de ligne : "_0", "_1", ... = numéro de la ligne
pi.getFormufle().getChamp("produit_0").setLibelle("Produit");
pi.getFormufle().getChampMulitple("montant").setVisible(false);   // cacher la colonne pour TOUTES les lignes
affichage.Champ.setAutre(pi.getFormufle().getChampFille("pu"), "onchange='calculerMontantV2()'");  // idem pour toutes
// boucle pour une valeur par défaut sur chaque ligne (l. 132-142)
for (int i = 0; i < nombreLigne; i++) {
    pi.getFormufle().getChamp("quantite_"+i).setDefaut("0");
    pi.getFormufle().getChamp("tva_"+i).setDefaut("0");
}
```
| Méthode | Cible |
|---|---|
| `getChamp("quantite_3")` | **une** ligne précise |
| `getChampMulitple("montant")` | **toutes** les lignes (visibilité, libellé…) |
| `getChampFille("pu")` | **toutes** les lignes (pour `affichage.Champ.setAutre / setPageAppelComplete`) |

### ④ Générer le HTML (l. 178-179) puis l'afficher (l. 195 et 205)
```java
pi.getFormu().makeHtmlInsertTabIndex();
pi.getFormufle().makeHtmlInsertTableauIndex();
...
out.println(pi.getFormu().getHtmlInsert());           // en-tête
out.println(pi.getFormufle().getHtmlTableauInsert()); // tableau des lignes
```

### ⑤ Le formulaire + les 6 champs cachés (l. 191 et 209-216)
```html
<form action="<%=pi.getLien()%>?but=apresMultiple.jsp" method="post"> ... </form>

<input name="acte"         type="hidden" value="insert">
<input name="classe"       type="hidden" value="faturefournisseur.As_BonDeCommande">
<input name="classefille"  type="hidden" value="faturefournisseur.As_BonDeCommande_Fille">
<input name="nombreLigne"  type="hidden" value="10">
<input name="colonneMere"  type="hidden" value="idbc">          <!-- colonne de la fille qui pointe la mère -->
<input name="bute"         type="hidden" value="bondecommande/bondecommande-arbiochem-fiche.jsp"> <!-- page après succès -->
<input name="nomtable"     type="hidden" value="AS_BONDECOMMANDE_FILLE">
```
→ ce sont ces champs que **`apresMultiple.jsp` lit** pour savoir quoi créer ✅. **Pour une nouvelle page : change juste ces valeurs.**

**Règles de comportement :**
- Seules les lignes **cochées** sont enregistrées (« Vous devez cocher » sinon).
- `colonneMere` = nom de l'attribut de la fille qui reçoit l'id de la mère (ici `idbc`).
- Pas de ligne remplie → refus ; une règle de `controler()` → alerte + retour.

## (2) La somme affichée en haut — c'est du JavaScript

### Où s'affiche-t-elle ? (l. 198-202) — un simple `<span>` avec un id
```html
<h3>Total : <span id="montanttotal">0</span><span id="deviseLibelle"> Ar</span></h3>
```

### Comment est-elle calculée ? (l. 273-293)
```javascript
function calculerMontantV2(){
    let montantTtc = 0;
    for (let i = 0; i < nombreLignes; i++) {
        let pu     = parseFloat(document.getElementById("pu_"+i)?.value       || 0);
        let qte    = parseFloat(document.getElementById("quantite_"+i)?.value || 0);
        let tva    = parseFloat(document.getElementById("tva_"+i)?.value      || 0);
        let remise = parseFloat(document.getElementById("remise_"+i)?.value   || 0);
        let ht = pu*qte - (pu*qte)*(remise/100);
        montantTtc += ht + ht*(tva/100);
    }
    let remiseMere = parseFloat(document.getElementById("remise")?.value || 0);   // champ de la mère
    montantTtc -= montantTtc*(remiseMere/100);
    document.getElementById("montanttotal").innerHTML = montantTtc.toLocaleString('en-US');
}
```
Les champs de lignes ont pour id **`<champ>_<numéro>`** (`pu_0`, `quantite_0`, `pu_1`…) ; ceux de la mère ont l'id du nom du champ (`remise`).

### Comment elle se met à jour ? — en branchant `onchange` sur les champs (l. 90, 126-137)
```java
pi.getFormu().getChamp("remise").setAutre("onchange='calculerMontantV2()'");           // champ de la mère
affichage.Champ.setAutre(pi.getFormufle().getChampFille("pu"),       "onchange='calculerMontantV2()'");
affichage.Champ.setAutre(pi.getFormufle().getChampFille("quantite"), "onchange='calculerMontantV2()'");
```
+ un premier calcul au chargement (l. 295-297) :
```javascript
document.addEventListener("DOMContentLoaded", function(){ calculerMontantV2(); });
```

## RECETTE — ma propre insertion multiple (ex. réception : lignes = pertes)
1. **Copier** `bondecommande-arbiochem-saisie.jsp` → `ma-saisie.jsp`.
2. Changer ① : `mere`, `fille`, `nombreLigne` (classes existantes : l'APJ lit leurs getters).
3. Garder ② ③ ce qui sert ; supprimer le reste (devise, taxe…).
4. Changer `setColOrdre` avec **tes** colonnes de ligne.
5. Changer les 6 champs cachés (⑤) : `classe`, `classefille`, `colonneMere`, `bute`, `nomtable`.
6. Pour une somme : `<span id="montanttotal">`, une fonction qui boucle sur `_0.._N`, des `setAutre("onchange='…'")`.
7. Tester : cocher, remplir, Enregistrer → arrive sur `bute`.

## Pièges
- Une ligne remplie mais **non cochée** → ignorée.
- `getChamp("x_0")` ne marche que si `x` est un attribut de la classe fille.
- Le total ne bouge pas → `setAutre("onchange=…")` oublié, ou id mal écrit (`_0`).
- Autocomplete d'une ligne : taper puis **cliquer une suggestion**, sinon l'id est vide (l. 328 efface la valeur).
- Les classes fille/mère doivent s'écrire avec leur **package complet** dans les champs cachés.

⚠ Non vu : le code interne de `PageInsertMultiple` (dans `apj-core.jar`) ; ce qui précède est ce que fait le JSP existant ✅.

### Sources — peur n°3 (fichier + lignes)
Fichier principal : `arbiochem-war/web/pages/bondecommande/bondecommande-arbiochem-saisie.jsp`
- ① mère+fille : l. 49-55 (`new As_BonDeCommande()`, `new As_BonDeCommande_Fille()`, `setNomTable("AS_BONDECOMMANDE_FILLE_CPL")`), l. 58 (`nombreLigne = 10`), l. 61 (`new PageInsertMultiple(...)`), l. 64 (`pi.setLien(...)`).
- ② mère : l. 101-139 (libellés, `setVisible(false)`, `setDefaut`, `setAutre("onchange='calculerMontantV2()'")` l. 137).
- ③ lignes : l. 287-289 (`setColOrdre`), l. 192-205 (libellés `_0` + `getChampMulitple().setVisible(false)`), l. 214-217 (`Champ.setAutre(... "onchange='calculerMontantV2()'")`), l. 228 (`preparerDataFormu()`), l. 231-240 (boucle `setDefaut("0")`).
- ④ HTML : l. 292-293 (`makeHtmlInsertTabIndex`, `makeHtmlInsertTableauIndex`), l. 316 (`getHtmlInsert`), l. 328 (`getHtmlTableauInsert`).
- ⑤ form + cachés : l. 311-313 (`<form action="...?but=apresMultiple.jsp" method="post">`), l. 321-323 (`<span id="montanttotal">`), l. 336-353 (`acte=insert` l. 339, `bute` l. 342, `classe` l. 345, `classefille` l. 346, `nombreLigne` l. 349, `colonneMere=idbc` l. 350, `nomtable=AS_BONDECOMMANDE_FILLE` l. 353).
- Somme JS : l. 417-440 (`calculerMontantV2()`), l. 443-445 (`DOMContentLoaded` → 1er calcul).
- Note : les n° de lignes `l. 50-55, 75-90, 104-142, 176-216, 273-297` cités plus haut venaient d'une version sans les gros commentaires ; correspondance ci-dessus = version actuelle du fichier.

---

# [ ] PEUR n°4 — « Je clique sur ENREGISTRER : qui prend mes données (1) ? qui les envoie en base (2) ? qui les affiche dans la fiche (3) ? »

**Réponse courte (✅ lu dans `apresMultiple.jsp`, `UserEJBBean.java` l. 3175 et `bondecommande-arbiochem-fiche.jsp`) :**

| # | Question | Qui | Où |
|---|---|---|---|
| 1 | Qui **prend** les données tapées ? | `PageInsertMultiple` (APJ, `apj-core.jar`), appelé par `apresMultiple.jsp` | `p.getObjectAvecValeur()` (mère) + `p.getObjectFilleAvecValeur()` (lignes cochées) |
| 2 | Qui **écrit** en base ? | `UserEJBBean.createObjectMultiple(...)` | `user/UserEJBBean.java` l. 3175, transaction + `createObject` |
| 3 | Qui **affiche** dans la fiche ? | `PageConsulte` (APJ) dans `bondecommande-arbiochem-fiche.jsp` | lit la base avec l'`id` reçu dans l'URL |

## Le trajet complet (7 pas)

```
saisie.jsp  ──[Enregistrer = POST]──▶  apresMultiple.jsp  ──▶  UserEJBBean  ──▶  Oracle
 (formulaire)                           (contrôleur)           (transaction)
                                                                    │ commit
 fiche.jsp  ◀──[redirection JS ?but=…fiche.jsp&id=BC000893]─────────┘
 (PageConsulte relit la base avec l'id)
```

### Pas 1 — Le navigateur envoie TOUT (POST)
Le `<form action="…?but=apresMultiple.jsp" method="post">` (saisie.jsp l. 191) envoie **tous** les champs : en-tête (`reference`, `fournisseur`, `daty`…), lignes (`produit_0`, `quantite_0`, `pu_0`…), cases cochées (`ids`) et les **champs cachés** (`acte`, `classe`, `classefille`, `colonneMere`, `nombreLigne`, `bute`, `nomtable`).
Le « `?but=apresMultiple.jsp` » passe par `module.jsp`, qui inclut `apresMultiple.jsp`.

### Pas 2 — (1) `apresMultiple.jsp` lit les paramètres et fabrique les objets (l. 81-114, 201-209)
```java
String acte = request.getParameter("acte");            // "insert"
String classe = request.getParameter("classe");        // faturefournisseur.As_BonDeCommande
mere  = (ClassMAPTable) Class.forName(classe).newInstance();        // objet VIDE
fille = (ClassMAPTable) Class.forName(classefille).newInstance();   // objet VIDE
PageInsertMultiple p = new PageInsertMultiple(mere, fille, request, nbLine, tId);
ClassMAPTable   cmere  = p.getObjectAvecValeur();       // mère REMPLIE depuis le formulaire
ClassMAPTable[] cfille = p.getObjectFilleAvecValeur();  // lignes COCHÉES remplies
```
→ **`PageInsertMultiple` (APJ) remplit les objets par NOM** : le paramètre `reference` va dans `setReference()`, `quantite_3` dans `setQuantite()` de la 4e ligne. D'où l'importance des getters/setters (peur n°2).
→ « Vous devez cocher » vient d'ici (aucune ligne cochée).

### Pas 3 — (2) `apresMultiple.jsp` appelle l'EJB (l. 210)
```java
ClassMAPTable o = (ClassMAPTable) u.createObjectMultiple(cmere, colonneMere, cfille);
```
`u` = l'utilisateur en session (`UserEJB`).

### Pas 4 — (2) `UserEJBBean.createObjectMultiple` écrit en base (l. 3175-3215)
Dans l'ordre :
1. **Droit** : `ActionRole.estAutorise(..."insert"...)` sinon « Action de creation non autorise… ».
2. Ouvre la connexion, `setAutoCommit(false)` → **une seule transaction**.
3. Si la mère est une `ClassMere` : `etat = créé (1)`, `iduser = utilisateur`, `mere.setFille(lignes)`.
4. `createObject(mere, c)` → **insère la mère** (génère la clé via `construirePK` → `BC000893`, lance `controler()`).
5. `createObjectMultiple(fille, colonneMere, idMere, c)` → pour chaque ligne : `ligne.setValChamp("idbc", idMere)` puis `createObject(ligne, c)` (clé `BCF…`, `controler()`).
6. `c.commit()`. En cas d'erreur : `c.rollback()` → **rien n'est enregistré** (ni mère ni lignes) et l'exception remonte.

> C'est **ici** que les règles de `controler()` (ex. « devises différentes », « Fournisseur manquant ») s'exécutent : message = alerte à l'écran.

### Pas 5 — `apresMultiple.jsp` récupère l'id créé (l. 211-216)
```java
idmere = o.getTuppleID();    // ex. BC000893
document.location.replace("<%=lien%>?but=<%=bute%>&id=<%=idmere%>");
```
= redirection JavaScript vers `module.jsp?but=bondecommande/bondecommande-arbiochem-fiche.jsp&id=BC000893`.
`bute` = le champ caché de la saisie ✅.

### Pas 6 — (3) La fiche lit la base avec cet `id` (fiche.jsp l. 62-68)
```java
As_BonDeCommandeCpl f = new As_BonDeCommandeCpl();
f.setNomTable("AS_BONDECOMMANDE_MERETRAITE");     // la VUE lue (avec libellés + statut livraison)
PageConsulte pc = new PageConsulte(f, request, u);
pc.getBase();                                      // le BC chargé depuis Oracle
String id = pc.getBase().getTuppleID();
```
→ `PageConsulte` (APJ) lit le paramètre **`id`** de l'URL, fait la requête sur la vue et remplit l'objet.
**Les données ne passent PAS d'une page à l'autre : seule l'`id` voyage, la fiche relit la base.**

### Pas 7 — (3) La fiche écrit les valeurs dans la page
```java
pc.getChampByName("fournisseurlib").setLibelle("Fournisseur");   // libellés, visibilité (l. 71-97)
pc.getChampByName("fournisseur").setVisible(false);
...
out.println(pc.getHtml());                                       // (l. 140) affiche le bloc d'infos
```
Les lignes (produits) sont affichées par l'onglet « Détails » : `bondecommande/inc/bondecommande-liste-detail.jsp` (inclus avec l'id du bon).
Les boutons Viser / Annuler pointent vers `apresTarif.jsp?acte=valider&id=…`.

## Pourquoi je ne vois pas la donnée dans la fiche ? (diagnostic)
| Symptôme | Cause probable |
|---|---|
| Alerte à l'enregistrement + retour au formulaire | une règle (`controler()`) ou « Vous devez cocher » → lire le message (`apresMultiple.jsp` l. 534-538) |
| Page blanche / rien | erreur avalée par un `try/catch` → `server.log` |
| Fiche vide ou « null » | `id` absent de l'URL, ou la **vue** lue (`setNomTable`) ne contient pas la ligne |
| Champ absent de la fiche | libellé/visibilité (`pc.getChampByName("x")`) ou colonne absente de la vue lue |
| Donnée enregistrée mais pas dans la liste | la liste lit une autre vue |

## À retenir
- **1 formulaire → 1 contrôleur générique → 1 méthode EJB → 1 transaction.** Le même chemin sert pour tous les modules ; seuls les **champs cachés** changent.
- **Qui touche à quoi ?** Tu règles les **noms** (classes, champs, vues) ; **APJ** fait le remplissage, l'insertion, la lecture.
- **Où mettre ma règle ?** `controler()` de la classe (ex. `As_BonDeCommande.controler`) — appelée au pas 4.
- ⚠ L'écriture dans `apresMultiple.jsp` a **aussi** une redirection finale en bas (l. 529) ; laquelle l'emporte reste à vérifier dans l'onglet Réseau du navigateur.
- ⚠ Non lu : le code de `PageInsertMultiple`, `PageConsulte` et de `createObject(…, Connection)` côté APJ (dans le JAR).

### Sources — peur n°4 (fichier + lignes)
- `arbiochem-war/web/pages/bondecommande/bondecommande-arbiochem-saisie.jsp` l. 311-313 (form `?but=apresMultiple.jsp`), l. 281-284 + 339-353 (les 6 cachés : `acte`, `classe`, `classefille`, `colonneMere=idbc`, `bute=...-fiche.jsp`, `nomtable`).
- `arbiochem-war/web/pages/apresMultiple.jsp` : BLOC 2 l. 59-79 (lecture `acte`, `classe`, `id`, `bute`), BLOC 3 l. 81-100 (`Class.forName(classe).newInstance()` l. 90 ; bascule `insert`→`updateInsert` l. 96-100) ; bloc `insert` l. 241-273 (`getObjectAvecValeur()` l. 250, `getObjectFilleAvecValeur()` l. 253, `u.createObjectMultiple(...)` l. 262, redirection `?but=<%=bute%>&id=<%=idmere%>` l. 271) ; bloc `valider` l. 594-604 (`u.validerObject(t)` l. 597, redirection l. 602) ; redirection finale par défaut l. 681-683 ; catch `alert + history.back()` l. 685-698.
- `arbiochem-ejb/src/java/user/UserEJBBean.java` l. 3175-3219 (`createObjectMultiple(mere, colonneMere, fille)` ; droit `insert` l. 3179 ; `etat=Créé` l. 3186 + `iduser` l. 3187 ; `createObject(mere, c)` l. 3192 ; `createObjectMultiple(fille, colonneMere, id, c)` l. 3197/3232-3246 ; `commit` l. 3208 / `rollback` l. 3211) ; `validerObject(o)` l. 2044-2061 et l. 937-948 (délègue à `ValiderObject`).
- `arbiochem-ejb/src/java/user/ValiderObject.java` l. 35-66 (recharge l'objet l. 43-53, refuse si `etat >= Valider` l. 55, `viser(user, c)` l. 57, sinon `updateEtat(..., getEtatValider(), ...)` l. 64).
- `arbiochem-ejb/src/java/faturefournisseur/As_BonDeCommande.java` l. 127-130 (`construirePK("BC","GETSEQBONCOMMANDE")`), l. 223-229 (`controler()` → `"Devise différent non accepté"`), l. 186-189 (`setFournisseur` → `"Fournisseur manquant"`), l. 70-75 (`annulerVisa` refuse si déjà validé).
- `arbiochem-war/web/pages/bondecommande/bondecommande-arbiochem-fiche.jsp` l. 44-45 (`new As_BonDeCommandeCpl()` + `setNomTable("AS_BONDECOMMANDE_MERETRAITE")`), l. 54 (`new PageConsulte`), l. 60-64 (`pc.getBase()` + `getTuppleID()`), l. 143-146 (`bc.getEtat()`), l. 170 (`pc.getHtml()`), l. 187-189 (bouton Viser → `apresTarif.jsp?acte=valider`), onglet Détails `inc/bondecommande-liste-detail.jsp` l. 247-249 + include l. 276-278.
- États : `CHEAT-SHEET-APJ.md` §6.5 l. 601-609 (`1 = créé`, `11 = validé`, `0 = annulé` ; `ConstanteEtat` est dans `apj-core.jar`, pas en source).

---

# [ ] PEUR n°5 — « La mère est en "Créé" : qui la passe en "Traité/Visé", et on retourne bien sur la fiche ? »

**En clair :** pour un BC, il n'y a pas d'état "Traité" sur la mère. Le cycle est **Créé (1) → Visé/Validé (11)**. C'est le **bouton `Viser` de la fiche** qui déclenche ça, via **`apresTarif.jsp` (acte=valider) → `UserEJBBean.validerObject()` → `ValiderObject.validerObject()` → `viser()` (= `UPDATE ... SET etat = 11`)**, puis **redirection vers la fiche** (`bute + &id=`). Oui, tu as raison : on retombe sur la fiche. Après (Réceptionner / Facturer), on ne change plus l'état du BC : on **crée d'autres objets** (BL, Facture) à partir du BC.

## Le trajet complet (4 pas)

```
fiche.jsp [bouton Viser] ──GET──▶ apresTarif.jsp?acte=valider&id=BCxxx ──▶ u.validerObject(t) ──▶ ValiderObject ──▶ UPDATE etat=11 ──▶ fiche.jsp?id=BCxxx
(PageConsulte relit la base avec l'id)
```

### Pas 1 — Le bouton `Viser` envoie TOUT (GET)
Le bouton `Viser` (fiche.jsp l. 187-189) envoie **4 infos** : `acte=valider` (quoi faire), `id` (quel BC), `classe` (quelle classe instancier), `bute` (où retourner).
```html
<a ... href="...?but=apresTarif.jsp&acte=valider&id=BCxxx&bute=bondecommande/bondecommande-arbiochem-fiche.jsp&classe=faturefournisseur.As_BonDeCommande">Viser</a>
```
- Visible seulement si `etat < 11` (fiche.jsp l. 184 : `if (etat < 11)` ; `etat` lu l. 143-146 via `bc.getEtat()`).
- Le « `?but=apresTarif.jsp` » passe par `module.jsp`, qui inclut `apresTarif.jsp`.

### Pas 2 — (1) `apresTarif.jsp` lit les paramètres et fabrique l'objet (l. 415-427)
```java
t = (ClassMAPTable) (Class.forName(classe).newInstance());   // l. 416 : objet VIDE par réflexion
t.setValChamp(t.getAttributIDName(), request.getParameter("id")); // l. 417 : pose l'id (ex. BC000893)
ClassMAPTable o = (ClassMAPTable) u.validerObject(t);        // l. 420 : ⭐ VALIDE
val = o.getTuppleID();                                        // l. 422
```
→ Même pattern que `apresMultiple.jsp` bloc `valider` l. 594-603, mais ici c'est **1 seul objet** (pas mère/fille).
→ `u` = l'utilisateur en session (`UserEJB`).

### Pas 3 — (1) `UserEJBBean.validerObject` + `ValiderObject` changent l'état (1 → 11)
Dans l'ordre :
1. **Droit** : `UserEJBBean.validerObject(o)` l. 2044-2061 (et l. 937-948) contrôle `validate` via `ActionRole`, ouvre la connexion, `setAutoCommit(false)` → **une seule transaction**, délègue à `ValiderObject`.
2. `ValiderObject.validerObject()` l. 35-66 recharge l'objet depuis la base (l. 43-53), refuse si `etat >= Valider` → `"objet deja vise"` (l. 55), puis `((ClassEtat) o).viser(user, c)` (l. 57) = **`UPDATE ... SET etat = 11`**, sinon `updateEtat(..., getEtatValider(), ...)` (l. 64).
3. `c.commit()`. En cas d'erreur : `c.rollback()` et l'exception remonte → `alert + history.back()` (catch final `apresTarif.jsp` l. 522-534).

> Valeurs (`CHEAT-SHEET-APJ.md` §6.5) : `1 = créé` (`getEtatCreer()`), `11 = validé/visé` (`getEtatValider()`), `0 = annulé`. Posé à la création dans `UserEJBBean.java` l. 3186.
> Garde-fou BC : `As_BonDeCommande.annulerVisa()` l. 70-75 refuse de dé-valider un BC déjà à `11`.

### Pas 4 — (2) `apresTarif.jsp` redirige vers la fiche (l. 424-426)
```java
document.location.replace("<%=lien%>?but=<%=bute%>&id=<%=val%>");
```
= redirection JavaScript vers `module.jsp?but=bondecommande/bondecommande-arbiochem-fiche.jsp&id=BC000893`.
`bute` = le paramètre donné par le bouton Viser ✅. **Oui, on retombe bien sur la fiche.**
La fiche relit la base avec cet `id` (`PageConsulte` + `pc.getBase()`, fiche.jsp l. 54-64) : elle affichera `etat = 11` et basculera sur les boutons du cas 2 (`etat >= 11` l. 203 : Acompte / Réceptionner / Facture).

### Ce qui ne change PAS l'état du BC (à ne pas confondre avec "Traité")
- `Réceptionner` (fiche.jsp l. 210-212 → `bondelivraison-arbiochem-saisie.jsp?id=BCxxx`) appelle `As_BonDeCommande.genererLivraison(u, c)` l. 466-492 → `genererBL()` l. 361-389 → crée un **nouveau** `As_BonDeLivraison` (`etat=1` l. 370) + ses filles, puis redirect vers `bondelivraison-modif.jsp?id=BL` (`apresLivraisonCommande.jsp` l. 18/25). Le BC reste à `11`.
- `Insertion Facture Fournisseur` (fiche.jsp l. 215-217 → `facturefournisseur-saisie.jsp?idbc=...`) appelle `genererFacture(u)` l. 239-286 : crée une **nouvelle** `Vente`/facture, puis redirect vers `facturefournisseur-modif.jsp` (`apresFacturer.jsp` l. 24/31). Le BC reste à `11`.
- La colonne `traite` / `Traite` vue dans la fiche (l. 103, `As_BonDeCommandeCpl` l. 14/48-54) et la vue `AS_BONDECOMMANDE_MERETRAITE` (l. 45) = **statut livraison/facturation calculé par la vue**, pas un `etat` que l'on `UPDATE`. D'où la confusion "Traité" : c'est un libellé de la vue, pas l'état workflow.

## Pourquoi je ne vois pas le changement d'état dans la fiche ? (diagnostic)
| Symptôme | Cause probable |
|---|---|
| Alerte + retour sur la fiche | objet déjà visé (`ValiderObject.java` l. 55) ou pas de droit `validate` → lire le message |
| Page blanche / rien | erreur avalée par un `try/catch` → `server.log` |
| Fiche toujours à `Créé` | `id` absent de l'URL, ou la **vue** lue (`setNomTable`) ne contient pas la ligne |
| Boutons Viser encore visibles | `etat` toujours `< 11` : la validation n'a pas `commit` (rollback après exception) |

## À retenir
- **1 bouton → 1 contrôleur générique → 1 méthode EJB → 1 transaction.** Le même chemin sert pour tous les modules ; seuls **`acte`, `id`, `classe`, `bute`** changent.
- **Qui touche à quoi ?** Tu règles les **boutons** (fiche) ; **APJ** fait le `UPDATE etat = 11` + la redirection.
- **Où mettre ma règle de validation ?** `validerObject(String u, Connection c)` de la classe — appelée au pas 3.
- ⚠ `apresTarif.jsp` a **aussi** une redirection finale par défaut en bas (l. 502-504) ; pour `valider` c'est la redirection du bloc (l. 424-426) qui compte.
- ⚠ Non lu : le code interne de `viser()` et de `updateEtat()` côté APJ (dans le JAR).

### Sources — peur n°5 (fichier + lignes)
- `arbiochem-war/web/pages/bondecommande/bondecommande-arbiochem-fiche.jsp` : l. 143-146 (`etat = bc.getEtat()`), l. 184 (`if (etat < 11)`), l. 187-189 (bouton `Viser` → `apresTarif.jsp&acte=valider&...&bute=...fiche.jsp&classe=...`), l. 203-217 (cas `etat >= 11`), l. 44-45 + 54-64 (lecture via `AS_BONDECOMMANDE_MERETRAITE` + `PageConsulte.getBase()`).
- `arbiochem-war/web/pages/apresTarif.jsp` : l. 415-427 (bloc `valider` : `Class.forName` l. 416, `setValChamp(id)` l. 417, `u.validerObject(t)` l. 420, redirect fiche l. 424-426) ; redirection défaut l. 502-504 ; catch `ValidationException` l. 506-521 + catch final l. 522-534.
- `arbiochem-war/web/pages/apresMultiple.jsp` (équivalent mère/fille) : l. 594-604 (bloc `valider`).
- `arbiochem-ejb/src/java/user/UserEJBBean.java` : l. 2044-2061 (`validerObject(o)` + `commit`), l. 937-948 (`validerObject(o, c)` → `ValiderObject`), l. 3186 (`etat = getEtatCreer()` à la création).
- `arbiochem-ejb/src/java/user/ValiderObject.java` : l. 35-66 (recharge l. 43-53, garde `deja vise` l. 55, `viser(user, c)` l. 57, `updateEtat(..., getEtatValider(), ...)` l. 64).
- `arbiochem-ejb/src/java/faturefournisseur/As_BonDeCommande.java` : l. 29 (`extends ClassMere`), l. 70-75 (`annulerVisa` refuse si `etat == getEtatValider()`), l. 361-389 (`genererBL`), l. 466-492 (`genererLivraison`), l. 239-286 (`genererFacture`), l. 289-295 (`createBL`).
- `arbiochem-ejb/src/java/faturefournisseur/As_BonDeCommandeCpl.java` : l. 14, 48-54 (`Traite`), l. 36-38 (table `As_BonDeCommande_MERECPL`).
- `arbiochem-war/web/pages/bondecommande/apresLivraisonCommande.jsp` : l. 21-25 (`genererLivraison(...)` puis redirect `bondelivraison/bondelivraison-modif.jsp&id=BL`).
- `arbiochem-war/web/pages/bondecommande/apresFacturer.jsp` : l. 27-31 (`genererFacture(...)` puis redirect `facturefournisseur/facturefournisseur-modif.jsp`).
- États : `CHEAT-SHEET-APJ.md` §6.5 l. 601-609 (`1 = créé`, `11 = validé`).

> Modèle pour tes futures peurs (n°6, 7, ...) : garde le même plan — question → réponse courte → trajet → pas-à-pas → diagnostic → à retenir → `### Sources` avec `fichier + lignes`.

---

# [ ] PEUR n°6 — « Comment ajouter une COLONNE sur une table + lire l'attribut d'un objet et l'utiliser n'importe où ? »

**En clair :** une colonne = la même info écrite à **5 endroits** (table → classe → vue(s) → saisie/liste/fiche → recompile). Et lire un attribut = **3 syntaxes selon où tu es** : `objet.getXxx()` en Java typé, `o.getValChamp("x")` en Java générique, `pc.getChampByName("x").getValeur()` dans une fiche JSP.

## (A) Ajouter une colonne — 5 morceaux (ex. `MONCHAMP` sur `AS_BONDECOMMANDE`)

```
Oracle (ALTER) ──▶ classe Java (attribut + getter/setter) ──▶ vue(s) _CPL/_LIB/MERETRAITE ──▶ JSP (saisie/liste/fiche) ──▶ compile/déploie
```

### ① La colonne Oracle (1 ligne)
```sql
ALTER TABLE AS_BONDECOMMANDE ADD (MONCHAMP VARCHAR2(100) DEFAULT '-');
```
- Type simple uniquement : `VARCHAR2` → `String`, `NUMBER` → `double`/`int` (jamais `Integer`/`Double`), `DATE` → `java.sql.Date` (piège `CHEAT-SHEET-APJ.md` §4.1).
- Mets un `DEFAULT` : un `int`/`double` sans valeur vaut `0`, un `String` sans valeur vaut `NULL` → fiche/liste vide.
- ⚠ Ici on **touche au SQL** : exception à la règle de la peur n°2 (qui disait « jamais le SQL » quand la colonne **existe déjà**). Si la colonne n'existe pas, c'est bien un `ALTER` + prévenir Mr Tahina.

### ② L'attribut Java + getter/setter (ex. `As_BonDeCommande.java` l. 31-68)
```java
private String monchamp;                        // nom = colonne en minuscule (APJ remplit par NOM)

public String getMonchamp() { return monchamp; }
public void setMonchamp(String v) { this.monchamp = v; }
```
- Copie le pattern d'un champ voisin : `id` l. 142-148, `daty` l. 150-156, `fournisseur` l. 182-189.
- Si règle métier (« refuser si vide ») : la mettre dans le setter comme `setFournisseur()` l. 186-189 (`throw new Exception("Fournisseur manquant")`), ou dans `controler()` l. 223-229.
- Côté fille, même pattern : `As_BonDeCommande_Fille.java` l. 22-34 (attributs), l. 94-100 (`getId`/`setId`), l. 102-108 (`getProduit`/`setProduit`), l. 80-83 (`construirePK`), l. 84-92 (`getTuppleID`/`getAttributIDName`).

### ③ La/les vue(s) lue(s) par les écrans (sinon `ORA-00904`)
- La saisie lit `AS_BONDECOMMANDE_FILLE_CPL` (`bondecommande-arbiochem-saisie.jsp` l. 55), la fiche/liste lit `AS_BONDECOMMANDE_MERETRAITE` (fiche l. 44-45, liste `bondecommande-arbiochem-liste.jsp` l. 47-48).
- Si ta colonne n'est pas dans la vue → champ visible mais vide, ou `ORA-00904 "MONCHAMP"` dans `server.log`.
```sql
CREATE OR REPLACE VIEW AS_BONDECOMMANDE_MERETRAITE AS SELECT ..., M.MONCHAMP, ... FROM AS_BONDECOMMANDE M ...;
CREATE OR REPLACE VIEW AS_BONDECOMMANDE_FILLE_CPL AS SELECT ..., D.MONCHAMP, ... FROM ...;
```
- Vérifie : `SELECT column_name FROM user_tab_columns WHERE table_name='AS_BONDECOMMANDE_MERETRAITE';`

### ④ Les 3 écrans (saisie / liste / fiche)
```java
// saisie (en-tête) — bondecommande-arbiochem-saisie.jsp l. 101-110 :
pi.getFormu().getChamp("monchamp").setLibelle("Mon champ");
// saisie (ligne) — même fichier l. 192-199 :
pi.getFormufle().getChamp("monchamp_0").setLibelle("Mon champ");  // _0 = ligne 0

// liste — bondecommande-arbiochem-liste.jsp l. 56-65 + 70-71 :
String listeCrt[] = {"id", "daty", ..., "monchamp"};              // cherchable
String libEntete[] = {"id", "daty", ..., "monchamp"};             // colonne affichée
PageRecherche pr = new PageRecherche(f, request, listeCrt, listeInt, 3, libEntete, libEntete.length);

// fiche — bondecommande-arbiochem-fiche.jsp l. 71-89 :
pc.getChampByName("monchamp").setLibelle("Mon champ");
// cacher : pc.getChampByName("monchamp").setVisible(false); (ex. l. 101-106)
```

### ⑤ Compiler / déployer (sinon ta colonne Java n'existe pas)
- Java modifié → `ant compile` (doit finir `BUILD SUCCESSFUL`), puis `ant deploy` (`CHEAT-SHEET-APJ.md` §5.1-5.2).
- JSP seule → copie dans `wildfly/.../async-standard.war/pages/...` **et** `build-file/arbiochem_war/pages/...` (pas de compile).
- Vue/colonne SQL → actif tout de suite, rien à déployer.

## (B) Lire l'attribut d'un objet et l'utiliser n'importe où — 3 syntaxes

| # | Où tu es | Comment lire | Exemple réel |
|---|---|---|---|
| 1 | Java, objet **typé** | `objet.getXxx()` | `bc.getFournisseur()` (fiche.jsp l. 207), `detail.getPu()` / `detail.getQuantite()` (`As_BonDeCommande_Fille.java` l. 52-63 `toFactureFournisseurDetails()`), `bc.getId()` / `getDaty()` (`As_BonDeCommande.java` l. 142-156) |
| 2 | Java **générique** (moteur, `apres*.jsp`, `UserEJBBean`) | `o.getValChamp("x")` / `o.getValInsert("x")` / `o.setValChamp("x", v)` | `o.getValInsert("id")` (`UserEJBBean.java` l. 2166, 3147, 3404), `liste[0].getValInsert("etat")` (l. 2082-2088), `t.setValChamp(id, ...)` (`apresTarif.jsp` l. 417, `apresMultiple.jsp` l. 555-556), `o.getValInsert(o.getAttributIDName())` (`ValiderObject.java` l. 64) |
| 3 | JSP **fiche** (`PageConsulte`) | `pc.getChampByName("x").getValeur()` | `pc.getChampByName("modepaiement").getValeur()` (fiche.jsp l. 207), `pc.getChampByName("id").getValeur()` (l. 216) |
| + | JSP **saisie/liste** + URL/session | `request.getParameter("id")`, `session.getValue("u"/"lien")` | `request.getParameter("id")` (fiche.jsp l. 143, 207-216), `session.getValue("u")` (saisie.jsp l. 35), `session.getValue("lien")` (saisie.jsp l. 64) |

- `getTuppleID()` = « donne-moi la clé » quel que soit son nom (`As_BonDeCommande.java` l. 132-140, `As_BonDeCommande_Fille.java` l. 84-92). `getAttributIDName()` = « comment s'appelle la clé » (`"id"`).
- Règle : en Java préfère `getXxx()` quand tu connais la classe (lisible) ; `getValChamp("x")` quand le code est générique (moteur APJ, boucle sur plusieurs classes).
- Piège : `getValChamp("MONCHAMP")` en majuscules vs attribut `monchamp` en minuscule → utilise le **nom d'attribut Java** (minuscule), pas le nom de colonne Oracle.

## RECETTE — ajouter `MONCHAMP` de A à Z
1. `ALTER TABLE ... ADD (MONCHAMP ...)` + vérifie `user_tab_columns`.
2. Attribut + getter/setter dans la classe (mère ou fille selon la table).
3. Ajoute la colonne dans chaque vue lue (`_CPL`, `MERETRAITE`).
4. `saisie.jsp` : `setLibelle` (+ `setColOrdre` l. 287-289 si colonne de ligne).
5. `liste.jsp` : ajoute dans `listeCrt` + `libEntete` (même ordre que `setLibelleAffiche`).
6. `fiche.jsp` : `getChampByName("monchamp").setLibelle(...)`.
7. `ant compile` + `ant deploy` (Java) ou copie JSP ; teste : saisie → fiche → liste.
8. Utilise-la où tu veux : `bc.getMonchamp()` (Java), `pc.getChampByName("monchamp").getValeur()` (fiche).

## Pièges
- Champ ajouté mais vide en liste/fiche → colonne absente de la **vue** lue (`setNomTable`), pas de la table.
- `ORA-00904` au 1er affichage → nom de colonne mal orthographié dans la vue ou la `Liste`.
- `Integer`/`Double` au lieu de `int`/`double` → « Erreur durant la recherche pagine … null » (§4.1).
- JSP modifiée mais invisible → Ant ne compile pas les JSP : copie vers WildFly + `build-file` (§5.2), lis `server.log` (§5.3).
- Colonne `NOT NULL` sans `DEFAULT` + ancien code qui ne la remplit pas → `INSERT` refusé.

### Sources — peur n°6 (fichier + lignes)
- `arbiochem-ejb/src/java/faturefournisseur/As_BonDeCommande.java` : l. 31-68 (attributs), l. 121-125 (constructeur `setNomTable`), l. 132-140 (`getTuppleID`/`getAttributIDName`), l. 142-156 (`getId`/`getDaty`), l. 182-189 (`getFournisseur`/`setFournisseur` + `throw`), l. 223-229 (`controler()`).
- `arbiochem-ejb/src/java/faturefournisseur/As_BonDeCommande_Fille.java` : l. 22-34 (attributs), l. 36-40 (constructeur + `setNomTable`/`setLiaisonMere`), l. 52-64 (`toFactureFournisseurDetails` : `getProduit()/getQuantite()/getPu()/getTva()`), l. 80-92 (`construirePK`, `getTuppleID`, `getAttributIDName`), l. 94-117 (`getId`/`setId`, `getProduit`/`setProduit`, `getIdbc`/`setIdbc`).
- `arbiochem-war/web/pages/bondecommande/bondecommande-arbiochem-saisie.jsp` : l. 49-64 (mère/fille + `setNomTable("AS_BONDECOMMANDE_FILLE_CPL")`), l. 101-110 (libellés en-tête), l. 192-199 (libellés `_0`), l. 287-289 (`setColOrdre`).
- `arbiochem-war/web/pages/bondecommande/bondecommande-arbiochem-liste.jsp` : l. 47-48 (`setNomTable("As_BonDeCommande_MERETRAITE")`), l. 56-58 (`listeCrt`/`listeInt`), l. 63-65 (`libEntete`), l. 70-71 (`new PageRecherche`), l. 111-114 (libellés recherche).
- `arbiochem-war/web/pages/bondecommande/bondecommande-arbiochem-fiche.jsp` : l. 44-45 (`setNomTable("AS_BONDECOMMANDE_MERETRAITE")`), l. 71-89 (`getChampByName(...).setLibelle`), l. 101-106 (`setVisible(false)`), l. 143 (`(As_BonDeCommandeCpl) pc.getBase()` + `bc.getEtat()`), l. 207 (`bc.getFournisseur()` + `pc.getChampByName("modepaiement").getValeur()`), l. 216 (`pc.getChampByName("id").getValeur()`).
- `arbiochem-war/web/pages/apresTarif.jsp` : l. 416-417 (`Class.forName` + `setValChamp(id)`).
- `arbiochem-war/web/pages/apresMultiple.jsp` : l. 555-556 (`setValChamp`), l. 594-604 (bloc `valider`).
- `arbiochem-ejb/src/java/user/UserEJBBean.java` : l. 2074-2088, 2166, 3147, 3404-3456 (`getValInsert`/`setValChamp`), l. 937-948 + 2044-2061 (`validerObject`).
- `arbiochem-ejb/src/java/user/ValiderObject.java` : l. 64 (`o.getValInsert(o.getAttributIDName())`).
- `CHEAT-SHEET-APJ.md` : §3.1 l. 217-251 (recette `capmax` : `ALTER` + attribut + vue), §4.1-4.5 (pièges types/`ORA-00904`/défaut), §5.1-5.2 l. 518-534 (`ant compile`/`ant deploy`, copie JSP), §6.5 l. 601-609 (états).
