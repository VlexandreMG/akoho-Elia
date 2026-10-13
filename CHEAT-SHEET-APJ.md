# CHEAT SHEET APJ — version débutant

> Projet **ARBIOCHEM** (akoho). Tous les exemples viennent du **vrai code du projet**,
> surtout du flux élevage : réception aéroport → réception usine → triage par compartiment.
> Les signatures ont été vérifiées dans `apj-core.jar` (avec `javap`).
> L'ancienne version est gardée dans `CHEAT-SHEET-APJ.ancien.md`.

**Comment lire ce document**
- §1 et §2 : comprendre comment APJ marche (à lire une fois).
- §3 : **« le prof me demande de… »** → une recette à copier, avec un exemple réel.
- §4 : les pièges qu'on a vraiment rencontrés.
- §5 : compiler, déployer, trouver une erreur.
- §6 : l'antisèche des méthodes.
- §7 : **la comparaison** : ce que fait APJ, et l'équivalent en **HTML pur** (côté JSP)
  et en **Java/SQL classique** (côté métier). À lire si une méthode APJ te paraît magique.

---

# 1. Comprendre APJ en 5 minutes

## 1.1 Le vocabulaire

| Mot | Ce que c'est | Exemple dans le projet |
|---|---|---|
| **Table** | Une table Oracle | `RECEPTIONUSINE` |
| **Classe métier** (EJB) | Une classe Java = une table. Un attribut = une colonne | `ferme.receptionusine.ReceptionUsine` |
| **Mère / fille** | Un document (mère) et ses lignes (filles) | `ReceptionUsine` (mère) et `ReceptionUsineDetail` (lignes) |
| **Page JSP** | Un écran | `pages/ferme/receptionusine/receptionusine-saisie.jsp` |
| **Champ** | Un input du formulaire, créé tout seul par APJ à partir d'un attribut Java | l'attribut `remarque` → `<input name="remarque">` |
| **État** | Le statut du document : 1 = créé, 11 = validé | colonne `etat` |

## 1.2 La règle magique d'APJ

> **Un attribut `private` dans la classe Java = une colonne dans la table = un input à l'écran.**

APJ lit les attributs de ta classe (par réflexion) et :
- fabrique **tout seul** les inputs du formulaire de saisie ;
- fait **tout seul** le `INSERT` / `UPDATE` / `SELECT`.

Tu n'écris donc presque jamais de HTML ni de SQL : tu **règles** les champs (libellé, caché,
liste déroulante…) dans la JSP, et tu mets tes **contrôles** dans la classe Java.

## 1.3 Le trajet d'une saisie

```
 Écran de saisie (xxx-saisie.jsp)
        │  l'utilisateur clique « Valider » → formulaire POST
        ▼
 apresMultiple.jsp           ← LE moteur de sauvegarde, commun à tout le projet
        │  lit les champs cachés : acte, classe, classefille...
        ▼
 ta classe Java . createObject(...)   ← TES CONTRÔLES (throw new Exception = message à l'écran)
        │
        ▼
 INSERT dans Oracle  →  redirection vers la fiche (xxx-fiche.jsp)
```

## 1.4 Toutes les pages passent par `module.jsp`

```
module.jsp?but=ferme/receptionusine/receptionusine-saisie.jsp&idlot=LOT000008
           └──────────── quel écran afficher ──────────────┘ └ paramètre ┘
```
`module.jsp` affiche le menu, l'en-tête, puis inclut la page indiquée par `but`.

## 1.5 Les 4 écrans d'un module

| Fichier | Classe APJ | Sert à |
|---|---|---|
| `xxx-liste.jsp` | `PageRecherche` | tableau + critères de recherche |
| `xxx-saisie.jsp` | `PageInsertMultiple` (ou `PageInsert` sans lignes) | créer |
| `xxx-fiche.jsp` | `PageConsulte` + onglet `inc/xxx-details.jsp` | voir un document, boutons Modifier / Valider |
| `xxx-modif.jsp` | `PageUpdateMultiple` | modifier (pas toujours présent) |

Exemple : `pages/ferme/receptionusine/` contient `receptionusine-liste.jsp`,
`receptionusine-saisie.jsp`, `receptionusine-fiche.jsp` et `inc/receptionusine-details.jsp`.

## 1.6 Où est le code ?

| Je cherche… | Dossier |
|---|---|
| une classe métier, un contrôle, un calcul | `arbiochem-ejb/src/java/...` (ex. `ferme/receptionusine/`) |
| un écran, un libellé, une liste déroulante | `arbiochem-war/web/pages/...` (ex. `ferme/receptionusine/`) |
| le moteur APJ (`affichage.*`, `bean.*`) | `build-file/lib/apj-core.jar` (pas de source) |
| la structure d'une table | SQL : `select column_name from user_tab_columns where table_name='LOT';` |

---

# 2. Les deux briques à connaître

## 2.1 La classe métier (Java)

```java
package ferme.receptionusine;

import bean.ClassMere;
import bean.ClassMAPTable;
import java.sql.Connection;

public class ReceptionUsine extends ClassMere {     // ClassMere = a des lignes
                                                    // (ClassEtat sans lignes, ClassFille pour une ligne)
    // ① UN ATTRIBUT PAR COLONNE — types SIMPLES uniquement (voir piège §4.1)
    private String id;
    private String idlot;
    private java.sql.Date daty;
    private double qterecus;
    private String remarque;
    // + getters / setters pour CHAQUE attribut (obligatoires : APJ s'en sert)

    // ② LE CONSTRUCTEUR : la table + le lien vers les lignes
    public ReceptionUsine() throws Exception {
        super.setNomTable("RECEPTIONUSINE");
        this.setNomClasseFille("ferme.receptionusine.ReceptionUsineDetail");
        this.setLiaisonFille("idmere");             // colonne des lignes qui pointe vers moi
    }

    // ③ LA CLÉ : préfixe + FONCTION Oracle qui donne le numéro suivant (piège §4.3)
    @Override
    public void construirePK(Connection c) throws Exception {
        this.preparePk("RUI", "GETSEQRECEPTIONUSINE");   // → RUI000001, RUI000002...
        this.setId(makePK(c));
    }

    @Override public String getTuppleID()       { return id; }
    @Override public String getAttributIDName() { return "id"; }

    // ④ LES CONTRÔLES : appelés à l'enregistrement
    @Override
    public ClassMAPTable createObject(String u, Connection c) throws Exception {
        if (this.getIdlot() == null || this.getIdlot().isEmpty()) {
            throw new Exception("Le lot est obligatoire.");   // ← s'affiche en alerte
        }
        return super.createObject(u, c);                       // ← fait l'INSERT
    }
}
```

La ligne (fille) suit le même modèle :
```java
public class ReceptionUsineDetail extends ClassFille {
    private String id, idmere, idqualitepoussin;
    private double qte;
    public ReceptionUsineDetail() throws Exception {
        super.setNomTable("RECEPTIONUSINEDETAIL");
        this.setNomClasseMere("ferme.receptionusine.ReceptionUsine");
        this.setLiaisonMere("idmere");
    }
    // construirePK avec "RUIF", "GETSEQRECEPTIONUSINEDETAIL", getTuppleID, getAttributIDName...
}
```

## 2.2 La page de saisie (JSP)

Le squelette de `receptionusine-saisie.jsp`, simplifié :

```jsp
<%@ page import="affichage.*, ferme.receptionusine.*, user.UserEJB" %>
<% try {
    UserEJB u = (UserEJB) session.getValue("u");

    ReceptionUsine       mere  = new ReceptionUsine();
    ReceptionUsineDetail fille = new ReceptionUsineDetail();
    int nbLignes = 3;
    PageInsertMultiple pi = new PageInsertMultiple(mere, fille, request, nbLignes, u);
    pi.setLien((String) session.getValue("lien"));

    // ── RÉGLAGES DE L'EN-TÊTE  : pi.getFormu().getChamp("nomAttribut")
    pi.getFormu().getChamp("daty").setLibelle("Date");
    pi.getFormu().getChamp("etat").setVisible(false);

    // ── RÉGLAGES DES LIGNES    : pi.getFormufle().getChamp("nomAttribut_0")   ← _0 !
    pi.getFormufle().getChamp("qte_0").setLibelle("Quantit&eacute;");

    pi.preparerDataFormu();                        // OBLIGATOIRE, après les réglages
    pi.getFormu().makeHtmlInsertTabIndex();
    pi.getFormufle().makeHtmlInsertTableauIndex();
%>
<div class="content-wrapper">
  <h1>R&eacute;ception usine</h1>
  <form action="<%=pi.getLien()%>?but=apresMultiple.jsp" method="post">
    <% out.println(pi.getFormu().getHtmlInsert()); %>          <!-- l'en-tête -->
    <% out.println(pi.getFormufle().getHtmlTableauInsert()); %> <!-- le tableau des lignes -->
    <input name="acte"        type="hidden" value="insert">
    <input name="bute"        type="hidden" value="ferme/receptionusine/receptionusine-fiche.jsp">
    <input name="classe"      type="hidden" value="ferme.receptionusine.ReceptionUsine">
    <input name="classefille" type="hidden" value="ferme.receptionusine.ReceptionUsineDetail">
    <input name="nomtable"    type="hidden" value="RECEPTIONUSINEDETAIL">
    <input name="nombreLigne" type="hidden" value="<%=nbLignes%>">
    <input name="colonneMere" type="hidden" value="idmere">
  </form>
</div>
<% } catch (Exception e) { e.printStackTrace(); %>
  <script>alert('<%=e.getMessage()%>'); history.back();</script>
<% } %>
```

| Champ caché | Rôle |
|---|---|
| `acte` | ce qu'il faut faire : `insert` (créer), `updateInsert` (modifier), `valider`... |
| `bute` | la page affichée **après** l'enregistrement |
| `classe` / `classefille` | les classes Java de la mère et des lignes (nom complet avec le package) |
| `nomtable` | la table des lignes |
| `nombreLigne` | le nombre de lignes du tableau |
| `colonneMere` | la colonne des lignes qui pointe vers la mère |

> ⚠ Dans le tableau des lignes, l'utilisateur doit **cocher** les lignes à enregistrer.
> Une ligne non cochée est ignorée ; s'il ne coche rien : « Vous devez cocher… ».

---

# 3. « Le prof me demande de… » — les recettes

> Pour chaque recette : **en-tête** = `pi.getFormu().getChamp("x")`,
> **lignes** = `pi.getFormufle().getChamp("x_0")` (avec `_0`) ou
> `pi.getFormufle().getChampFille("x")` (toutes les lignes d'un coup).

## 3.1 Ajouter un nouvel input (un nouveau champ) ⭐

Exemple réel : on a ajouté **« Capacité max »** sur les lignes du triage (`capmax`).

**① La colonne Oracle**
```sql
ALTER TABLE TRIAGEBATIMENTPARQUETDETAIL ADD (capmax NUMBER DEFAULT 0);
```

**② L'attribut Java** (dans `TriageBatimentParquetDetail.java`) + getter / setter
```java
private double capmax;                       // double, PAS Double (piège §4.1)

public double getCapmax()            { return capmax; }
public void   setCapmax(double v)    { this.capmax = v; }
```
→ Rien d'autre à faire : APJ crée l'input `capmax_0`, `capmax_1`... **tout seul**.

**③ Le libellé dans la JSP** (`triagebatimentparquet-saisie.jsp`)
```java
pi.getFormufle().getChamp("capmax_0").setLibelle("Capacit&eacute; max");
```

**④ Si la page lit une VUE** (`..._LIB`), ajouter la colonne dans la vue, sinon la liste plante :
```sql
CREATE OR REPLACE VIEW TRIAGEBATPARQUETDETAIL_LIB AS
SELECT d.ID, d.IDMERE, ..., d.CAPMAX, ...   -- ← ajoutée
```

**⑤ Compiler + déployer** (§5).

Pour un champ **d'en-tête**, c'est pareil, sans `_0` :
```java
pi.getFormu().getChamp("remarque").setLibelle("Remarque");
```

## 3.2 Changer le texte (libellé) d'un champ

```java
pi.getFormu().getChamp("idlot").setLibelle("Lot");                  // en-tête
pi.getFormufle().getChamp("qte_0").setLibelle("Quantit&eacute;");   // lignes
```
Accents en HTML : `&eacute;` é · `&egrave;` è · `&ecirc;` ê · `&agrave;` à · `&acirc;` â ·
`&ccedil;` ç · `&ocirc;` ô · `&sup2;` ².

## 3.3 Cacher un champ

```java
// En-tête
pi.getFormu().getChamp("etat").setVisible(false);

// Lignes : TOUTES les lignes d'un coup (méthode statique de Champ)
affichage.Champ.setVisible(pi.getFormufle().getChampFille("idbatiment"), false);
```
Un champ caché est **quand même envoyé** (input `hidden`) avec sa valeur par défaut.
⚠ Un `int` / `double` caché sans valeur vaut **0** (piège §4.5).

## 3.4 Mettre une valeur par défaut / lecture seule

```java
pi.getFormu().getChamp("idlot").setDefaut(idlot);       // pré-rempli
pi.getFormu().getChamp("idlot").setAutre("readonly");   // non modifiable

// Exemple réel : arriver sur la saisie usine depuis la fiche aéroport
String idlot = request.getParameter("idlot");
if (idlot != null && !idlot.isEmpty()) {
    pi.getFormu().getChamp("idlot").setDefaut(idlot);
    pi.getFormu().getChamp("idlot").setAutre("readonly");
}
```
`setAutre("...")` ajoute n'importe quel attribut HTML : `readonly`,
`onchange='maFonction()'`, `style='width:80px'`...

## 3.5 Changer le type d'un input

```java
pi.getFormu().getChamp("heuredepart").setType("time");      // heure
pi.getFormu().getChamp("daty").setType("date");             // date
pi.getFormu().getChamp("remarque").setType("textarea");     // texte long
pi.getFormu().getChamp("qte").setType("number");            // nombre
pi.getFormufle().getChamp("remarque_0").setTaille(20);      // largeur
```

## 3.6 Une liste déroulante (select) remplie depuis une table ⭐

```java
Liste[] liste = new Liste[2];

// new Liste("nomDuChamp", source, "colonne AFFICHÉE", "colonne ENREGISTRÉE")
liste[0] = new Liste("idsexe", new TypeObjet("SEXE"), "val", "id");

// Avec un filtre SQL (commence par " and ...") et une valeur choisie par défaut
liste[1] = new Liste("etatsante", new TypeObjet("ETATSANTE"), "val", "id");
liste[1].setApresW(" and id >= 1");
liste[1].setDefaultSelected("10");             // « Sain » sélectionné

pi.getFormufle().changerEnChamp(liste);       // lignes   (pi.getFormu() pour l'en-tête)
```
- `TypeObjet("TABLE")` sert pour toute table simple `ID, VAL, DESCE` (nomenclatures).
- Sinon, on passe la classe : `new Liste("idlot", new Lot(), "nomlot", "id")`.
- ⚠ Les colonnes utilisées (`val`, `actif` dans `setApresW`...) **doivent exister** dans la
  table, sinon page blanche (piège §4.4).
- ⚠ Pour une grosse table (personnel : 465 lignes), préférer l'**autocomplétion** (§3.8).

## 3.7 Une liste déroulante avec des valeurs fixes

```java
Liste oui = new Liste("estactif");
oui.makeListeString(new String[]{"Oui", "Non"},     // ce qu'on VOIT
                    new String[]{"1",   "0"});      // ce qu'on ENREGISTRE
pi.getFormu().changerEnChamp(new Liste[]{ oui });

// Ajouter un choix vide « - » à une liste existante :
liste[0].ajouterValeur(new String[]{""}, new String[]{"-"});   // (valeurs, libellés)
```

## 3.8 Une autocomplétion (champ qui propose en tapant) ⭐

Exemple réel (`receptionusine-saisie.jsp`) : véhicule et chauffeur.
```java
//                     setPageAppelComplete(classe Java,  colonne clé, table ou vue, col. affichée, col. renvoyée)
pi.getFormu().getChamp("idvehicule")
  .setPageAppelComplete("ferme.configuration.Vehicule", "id", "VEHICULE", "id", "id");
pi.getFormu().getChamp("idchauffeur")
  .setPageAppelComplete("paie.log.LogPersonnel", "id", "LOG_PERSONNEL", "id", "id");

// Version courte (3 arguments) :
pi.getFormu().getChamp("idlot").setPageAppelComplete("ferme.lot.Lot", "id", "LOT");

// Sur les LIGNES (statique, toutes les lignes) :
affichage.Champ.setPageAppelComplete(pi.getFormufle().getChampFille("idparquet"),
        "ferme.configuration.Parquet", "id", "PARQUET", "", "");
```

## 3.9 Le petit bouton « + » pour créer l'élément sans quitter la page

```java
pi.getFormu().getChamp("idClient").setPageAppelInsert(
        "client/client-saisie.jsp",          // la page de création
        "idClient;idClientlibelle",          // les champs de MA page à remplir
        "id;nom");                           // avec ces colonnes de l'élément créé
```

## 3.10 Changer l'ordre des colonnes / des champs

```java
// Lignes : ordre des colonnes du tableau (noms SANS _0)
pi.getFormufle().setColOrdre(new String[]{"idparquet","capmax","idsexe","qte","etatsante","remarque"});

// En-tête : ordre des champs
pi.getFormu().setOrdre(new String[]{"daty","idlot","remarque"});
```

## 3.11 Ajouter une colonne dans une LISTE (+ un total en bas)

Dans `xxx-liste.jsp` :
```java
String[] libEntete = {"id","idLotLib","daty","dispo","ecart","etatlib"};   // colonnes (= attributs)
PageRecherche pr = new PageRecherche(o, request, listeCrt, listeInt, 4, libEntete, libEntete.length);

String[] colSomme = {"dispo","ecart"};        // colonnes totalisées en bas (null = aucun total)
pr.creerObjetPage(libEntete, colSomme);

pr.getTableau().setLibelleAffiche(new String[]{"Id","Lot","Date","Vivants","Non r&eacute;partis","&Eacute;tat"});
// ⚠ setLibelleAffiche : AUTANT de libellés que de colonnes dans libEntete
```
Affichage dans la page :
```jsp
<% out.println(pr.getFormu().getHtmlEnsemble()); %>   <!-- les critères de recherche -->
<% out.println(pr.getTableauRecap().getHtml()); %>    <!-- la ligne des totaux -->
<% out.println(pr.getTableau().getHtml()); %>         <!-- le tableau -->
<% out.println(pr.getBasPage()); %>                    <!-- la pagination -->
```
Filtrer la liste : `pr.setAWhere(" and idmere='" + id + "'");`
(⚠ pas de `order by` dans `setAWhere` quand il y a un `colSomme`).

## 3.12 Ajouter un bouton / un lien

```jsp
<!-- dans une fiche : un bouton qui ouvre la saisie suivante, avec un paramètre -->
<a class="btn btn-secondary pull-right"
   href="<%= lien %>?but=ferme/receptionusine/receptionusine-saisie.jsp&idlot=<%= base.getIdLot() %>">
   R&eacute;ception usine</a>
```
```java
// dans une liste : un bouton à côté des critères
pr.getFormu().setAnotherButton(
    "<a class=\"btn btn-primary\" href=\"module.jsp?but=ferme/receptionusine/receptionusine-saisie.jsp\">Nouveau</a>");
```

## 3.13 Ajouter un contrôle (« refuser si… ») ⭐

Toujours dans la **classe Java**, jamais dans la JSP. On lance une exception : son message
s'affiche en alerte et rien n'est enregistré.

```java
// Une règle sur une ligne (exemple réel : TriageBatimentParquet.checkLigne)
public static void checkLigne(TriageBatimentParquetDetail d) throws Exception {
    if (d.getCapmax() <= 0)
        throw new Exception("La capacité max du parquet " + d.getIdparquet() + " est obligatoire.");
    if (d.getQte() <= 0)
        throw new Exception("La quantité d'une ligne doit être supérieure à 0.");
}

// Appelée à l'enregistrement
@Override
public ClassMAPTable createObject(String u, Connection c) throws Exception {
    TriageBatimentParquetDetail[] lignes = (TriageBatimentParquetDetail[]) this.getFille();
    for (TriageBatimentParquetDetail d : lignes) checkLigne(d);
    return super.createObject(u, c);
}
```

| Je veux contrôler… | Méthode à redéfinir |
|---|---|
| à la création | `createObject(String u, Connection c)` |
| à la création d'une **ligne** seule | `controler(Connection c)` dans la classe fille |
| à la validation (état → 11) | `validerObject(String u, Connection c)` |
| à la modification | `controlerUpdate(Connection c)` |

Les contrôles communs au flux sont dans `ferme/utils/ControlePoussin.java`
(`checkSomme`, `checkAntecedent`, `checkParquet`, `checkCapParquet`...).

## 3.14 Lire des données en Java

```java
import bean.CGenUtil;

// Plusieurs lignes → un tableau d'objets
Lot[] lots = (Lot[]) CGenUtil.rechercher(new Lot(), null, null, " and idbc = 'BC001210'");
Lot[] lots = (Lot[]) CGenUtil.rechercher(new Lot(), null, null, c, " and etat >= 11");  // avec connexion

// Une seule valeur (somme, compte, max...) → un Object
Object o = CGenUtil.rechercherSimple("select nvl(sum(qte),0) from TRIAGEBATIMENTPARQUETDETAIL where idmere='TB000007'", c);
double total = (o instanceof Number) ? ((Number) o).doubleValue() : 0;
```
⚠ **Jamais** `CGenUtil.rechercher(objet, " and ...")` à 2 arguments : le 2ᵉ est pris pour un
nom de table → `ORA-00903` (piège §4.2).

## 3.15 Afficher une valeur calculée (une vue SQL + une classe)

Exemple réel : le bilan de la réception usine (attendus, morts, perdus, vivants).
1. Une vue : `CREATE VIEW RECEPTIONUSINE_LIB AS SELECT ... AS id, ..., nbmort, nbperdu, nbvivant ...`
   (elle doit avoir une colonne `id`).
2. Une classe qui la lit (`ReceptionUsineLib`, `setNomTable("RECEPTIONUSINE_LIB")`,
   des attributs `double` / `String`).
3. Une `PageRecherche` dessus dans la JSP, avec `colSomme` pour le total.

## 3.16 Ajouter une entrée dans le menu

Le menu est dans la table `MENUDYNAMIQUE` (`ID, LIBELLE, ICONE, HREF, RANG, NIVEAU, ID_PERE`).
Exemple réel : `sql/schema_elevage.sql` §6.
```sql
INSERT INTO menudynamique (id, libelle, icone, href, rang, niveau, id_pere)
VALUES ('MENDYNRUSINE', UNISTR('R\00E9ception usine'), 'local_shipping', '#', 5, 3, 'MENDYN178852629779187');
INSERT INTO menudynamique (id, libelle, icone, href, rang, niveau, id_pere)
VALUES ('MENDYNRUSINE01', 'Saisie', 'add',
        'module.jsp?but=ferme/receptionusine/receptionusine-saisie.jsp', 1, 4, 'MENDYNRUSINE');
COMMIT;
```
`id_pere` = la rubrique parente ; `niveau` = profondeur ; `icone` = nom d'icône Material.
→ Se **déconnecter / reconnecter** pour voir le menu.

## 3.17 Créer un nouveau document de A à Z (checklist)

1. **Tables** : `MON_DOC (id, daty, etat, ...)` et `MON_DOC_DETAIL (id, idmere, ...)`.
2. **Séquences + fonctions** (APJ appelle une **fonction**, piège §4.3) :
   ```sql
   CREATE SEQUENCE SEQ_MONDOC;
   CREATE OR REPLACE FUNCTION GETSEQMONDOC RETURN NUMBER IS r NUMBER;
   BEGIN SELECT SEQ_MONDOC.NEXTVAL INTO r FROM DUAL; RETURN r; END;
   /
   ```
3. **Classes Java** mère + fille (modèle §2.1).
4. **Pages** : copier celles de `ferme/receptionusine/` et remplacer les noms.
5. **Menu** (§3.16).
6. **Compiler, déployer, tester** (§5).

---

# 4. Les pièges (tous rencontrés pour de vrai)

| # | Symptôme | Cause | Solution |
|---|---|---|---|
| 4.1 | « Erreur durant la recherche pagine … null » | un attribut `Integer` / `Double` dans une classe APJ | types **simples** : `int`, `double`, `String`, `java.sql.Date` |
| 4.2 | `ORA-00903` (nom de table non valide) | `CGenUtil.rechercher(obj, " and ...")` à 2 arguments | `CGenUtil.rechercher(obj, null, null, " and ...")` |
| 4.3 | page blanche après « Valider », `ORA-00904 "GETSEQ..."` | `preparePk("X","GETSEQX")` attend une **FONCTION**, pas une séquence | créer `SEQ_X` + la fonction `GETSEQX` (§3.17) |
| 4.4 | page de saisie blanche, `ORA-00904 "ACTIF"` (ou `"VAL"`) | une `Liste` filtre ou affiche une colonne qui n'existe pas dans la table | vérifier les colonnes (`user_tab_columns`) ou passer en autocomplétion |
| 4.5 | l'élément créé n'apparaît dans aucune liste | un champ `int actif` caché vaut 0 ; ou colonne non mappée qui reste NULL | `this.setActif(1)` dans `createObject`, ou `DEFAULT 1` sur la colonne |
| 4.6 | les lignes sont en double après « Modifier » | la saisie renvoie `acte=insert` : APJ met à jour l'en-tête mais recrée les lignes | `ControlePoussin.preparerModification(...)` au début de `createObject` (déjà fait sur le flux) |
| 4.7 | une valeur à 0 alors que le PU est saisi | `AS_BONDECOMMANDE_FILLE.montant` souvent à 0 | utiliser `quantite × pu` quand `montant = 0` |
| 4.8 | « Vous devez cocher » | aucune ligne cochée dans le tableau | cocher les lignes à enregistrer |
| 4.9 | ma modif JSP ne compile pas / pas visible | Ant ne compile **pas** les JSP ; elles le sont au 1er affichage | lire le log WildFly (§5.3) |
| 4.10 | une ligne SQL*Plus ignorée sans erreur | `INSERT ...;  -- commentaire` sur la même ligne | commentaire sur **sa propre ligne** |
| 4.11 | erreur sur une liste avec totaux | `order by` dans `setAWhere` + `colSomme` | trier autrement (pas dans `setAWhere`) |
| 4.12 | accents cassés dans un script SQL | encodage du fichier | `UNISTR('R\00E9ception')` |

---

# 5. Compiler, déployer, trouver une erreur

## 5.1 Compiler le Java (vérifier qu'il n'y a pas d'erreur)

```bash
cd "C:/Users/Admin/Documents/S6/akoho/projet-standard - Copie"
JAVA_HOME="/c/Program Files/BellSoft/LibericaJDK-8" /d/apache-ant-1.10.18/bin/ant compile
```
→ doit finir par `BUILD SUCCESSFUL`. (Ant n'est pas dans le PATH ; `JAVA_HOME` doit pointer
vers le JDK 8 Liberica.)

## 5.2 Déployer

| J'ai modifié… | Que faire |
|---|---|
| **seulement une JSP** | copier la JSP dans `D:\wildfly-10.0.0.Final\standalone\deployments\async-standard.war\pages\...` (rechargée toute seule) **et** dans `build-file\arbiochem_war\pages\...` |
| **du Java** | `ant deploy` (compile, fabrique le jar, copie tout vers WildFly et redéploie) |
| **la base** (vue, colonne) | rien : c'est actif tout de suite |
| **le menu** | se déconnecter / reconnecter |

## 5.3 Trouver une erreur (page blanche, message bizarre)

1. Ouvrir le log : `D:\wildfly-10.0.0.Final\standalone\log\server.log`.
2. Chercher `ORA-` ou `Exception` près de l'heure de l'erreur.
3. Juste au-dessus, APJ affiche la requête SQL exécutée (`Requete select rechercher : ...`).
4. La ligne `at ferme....java:48` donne le fichier et la ligne Java en cause.

Exemple réel :
```
Requete select rechercher : select * from VEHICULE where 1<2  and actif = 1 order by val ASC
java.sql.SQLException: ORA-00904: "ACTIF" : identificateur non valide
    at org.apache.jsp.pages.ferme.receptionusine.receptionusine_002dsaisie_jsp...
```
→ la page `receptionusine-saisie.jsp` filtre `VEHICULE` sur une colonne `actif` qui n'existe pas.

---

# 6. Antisèche des méthodes

## 6.1 `Champ` (un input) — `getChamp("x")`

| Méthode | Effet |
|---|---|
| `setLibelle("Texte")` | le texte affiché |
| `setVisible(false)` | cacher |
| `setDefaut("valeur")` | valeur par défaut |
| `setAutre("readonly")` | attribut HTML libre (`readonly`, `onchange='...'`) |
| `setType("date")` | `date`, `time`, `number`, `textarea`... |
| `setTaille(20)` | largeur |
| `setPageAppelComplete(classe, colCle, table, colAffiche, colRetour)` | autocomplétion |
| `setPageAppelInsert(page, champsAremplir, colonnes)` | bouton « + » |
| `Champ.setVisible(champs[], false)` | statique : toutes les lignes |

## 6.2 `Liste` (un select)

| Méthode | Effet |
|---|---|
| `new Liste("champ", source, "colAffichee", "colValeur")` | liste depuis une table / classe |
| `new Liste("champ")` + `makeListeString(libelles, valeurs)` | liste de valeurs fixes |
| `setApresW(" and ...")` | filtre SQL |
| `setDefaultSelected("10")` | valeur sélectionnée |
| `ajouterValeur(valeurs, libelles)` | ajouter des choix |
| `setDeroulanteDependante(autreListe, "colonne", "onchange")` | liste qui dépend d'une autre |
| `formu.changerEnChamp(listes[])` | **appliquer** les listes au formulaire |

## 6.3 `Formulaire` — `pi.getFormu()` (en-tête) / `pi.getFormufle()` (lignes)

| Méthode | Effet |
|---|---|
| `getChamp("x")` / `getChamp("x_0")` | un champ (lignes : avec `_0`) |
| `getChampFille("x")` | toutes les lignes d'un champ (tableau) |
| `changerEnChamp(listes)` | appliquer des listes déroulantes |
| `setOrdre(...)` / `setColOrdre(...)` | ordre des champs / des colonnes |
| `setAnotherButton("<a ...>")` | ajouter un bouton |

## 6.4 Les pages

| Classe | Écran | À appeler avant d'afficher |
|---|---|---|
| `PageRecherche` | liste | `creerObjetPage(libEntete, colSomme)` |
| `PageInsert` | saisie simple | `preparerDataFormu()` |
| `PageInsertMultiple` | saisie mère + lignes | `preparerDataFormu()` |
| `PageUpdateMultiple` | modification mère + lignes | `preparerDataFormu()` |
| `PageConsulte` | fiche | — |

## 6.5 Les états — `utilitaire.ConstanteEtat`

| Valeur | Sens | Code |
|---|---|---|
| 1 | créé (brouillon) | `ConstanteEtat.getEtatCreer()` |
| **11** | **validé** | `ConstanteEtat.getEtatValider()` |
| 0 | annulé | |

Dans le flux élevage, on ne compte que ce qui est **validé** (`etat >= 11`).

## 6.6 La session dans une JSP

```java
UserEJB u    = (UserEJB) session.getValue("u");      // l'utilisateur connecté
String  lien = (String)  session.getValue("lien");   // "module.jsp" (pour construire les liens)
String  id   = request.getParameter("id");           // un paramètre de l'URL
```

## 6.7 Les constantes élevage — `ferme/utils/ConstanteFerme.java`

```java
IDSEXEMALE = "1";  IDSEXEFEMELLE = "0";
qualiteConforme = "QP000001";  qualiteMort = "QP000022";  qualitePerdu = "QP000023";
```

---

---

# 7. Comparaison : APJ ↔ HTML pur ↔ Java/SQL classique

> APJ écrit le HTML et le SQL **à ta place**. Cette section montre, pour chaque appel APJ,
> ce que tu aurais dû écrire **sans** APJ.
> Le HTML « généré » a été **produit pour de vrai** par `apj-core.jar`, puis simplifié :
> APJ ajoute toujours `class=form-control`, un `data-type`, et un petit
> `<input type=hidden name=xxxauto>` en plus, qu'on peut ignorer.

## 7.1 Côté écran (JSP) : APJ → HTML

### Un champ texte
```java
// APJ (dans la JSP)
pi.getFormu().getChamp("remarque").setLibelle("Remarque");
```
```html
<!-- Ce qu'APJ génère (simplifié) -->
<label>Remarque</label>
<input name="remarque" id="remarque" type="textbox" class="form-control" value="">
```
```html
<!-- Ce que tu écrirais en HTML pur -->
<label for="remarque">Remarque</label>
<input type="text" name="remarque" id="remarque">
```
> Le `name` de l'input = le **nom de l'attribut Java**. C'est comme ça qu'APJ retrouve la
> valeur à l'enregistrement : `request.getParameter("remarque")` → `setRemarque(...)`.

### Changer le type (date, heure, nombre, texte long)
| APJ | HTML généré |
|---|---|
| `getChamp("daty").setType("date")` | `<input name="daty" type="date" ...>` |
| `getChamp("heuredepart").setType("time")` | `<input name="heuredepart" type="time" ...>` |
| `getChamp("qte").setType("number")` | `<input name="qte" type="number" ...>` |
| `getChamp("remarque").setType("textarea")` | `<textarea name="remarque" ...></textarea>` |

### Valeur par défaut, lecture seule, événement
| APJ | HTML généré |
|---|---|
| `getChamp("idlot").setDefaut("LOT000008")` | `<input name="idlot" value="LOT000008" ...>` |
| `getChamp("idlot").setAutre("readonly")` | `<input name="idlot" ... readonly>` |
| `getChamp("qte").setAutre("onchange='calculer()'")` | `<input name="qte" ... onchange='calculer()'>` |

> `setAutre("...")` = « colle ce texte tel quel dans la balise ». Tout attribut HTML marche :
> `readonly`, `required`, `placeholder='...'`, `style='...'`, `onclick='...'`.

### Cacher un champ
```java
pi.getFormu().getChamp("etat").setVisible(false);       // APJ
```
```html
<input type="hidden" name="etat" id="etat" value="1">    <!-- HTML généré -->
```
> Le champ n'est pas supprimé : il est **caché**, et sa valeur est **quand même envoyée**.

### Une liste déroulante
```java
// APJ : valeurs fixes
Liste l = new Liste("idsexe");
l.makeListeString(new String[]{"Male","Femelle"}, new String[]{"1","0"});
l.setDefaultSelected("0");
pi.getFormu().changerEnChamp(new Liste[]{ l });
```
```html
<!-- HTML généré (réel) -->
<select name="idsexe" id="idsexe" class="form-control">
  <option value="1">Male</option>
  <option value="0" selected>Femelle</option>
</select>
```
```java
// APJ : valeurs lues dans une table
new Liste("idsexe", new TypeObjet("SEXE"), "val", "id");
```
```jsp
<%-- Équivalent JSP + JDBC sans APJ --%>
<select name="idsexe">
<%  ResultSet rs = stmt.executeQuery("select id, val from SEXE order by val");
    while (rs.next()) { %>
      <option value="<%= rs.getString("id") %>"><%= rs.getString("val") %></option>
<%  } %>
</select>
```
> Dans `new Liste("nom", source, "val", "id")` : `"val"` = le **texte** de l'`<option>`,
> `"id"` = sa **value**. `setApresW(" and id >= 1")` ajoute `and id >= 1` au `where` du `select`.

### Les lignes d'un tableau (mère / fille)
```java
pi.getFormufle().getChamp("qte_0").setLibelle("Quantit&eacute;");    // APJ
```
```html
<!-- Principe du HTML généré : une ligne de tableau par ligne, suffixe _0, _1, _2... -->
<tr>
  <td><input type="checkbox" ...></td>        <!-- la case à cocher de la ligne -->
  <td><input name="idparquet_0"></td>
  <td><input name="qte_0" type="number"></td>
</tr>
<tr>
  <td><input type="checkbox" ...></td>
  <td><input name="idparquet_1"></td>
  <td><input name="qte_1" type="number"></td>
</tr>
```
> C'est pour ça qu'on écrit `getChamp("qte_0")` : `_0` = la 1re ligne.
> `getChampFille("qte")` renvoie **toutes** les lignes (`qte_0`, `qte_1`...) d'un coup.
> Une ligne dont la case n'est pas cochée n'est pas enregistrée.

### Le formulaire et son envoi
```jsp
<%-- APJ : on poste TOUJOURS vers le moteur commun --%>
<form action="module.jsp?but=apresMultiple.jsp" method="post">
  <% out.println(pi.getFormu().getHtmlInsert()); %>
  <input type="hidden" name="acte"   value="insert">
  <input type="hidden" name="classe" value="ferme.receptionusine.ReceptionUsine">
  ...
</form>
```
```html
<!-- Sans APJ : en général une servlet par écran -->
<form action="ReceptionUsineServlet" method="post">
  <input name="idlot"> <input name="daty" type="date"> ...
  <button type="submit">Enregistrer</button>
</form>
```

### La page liste
```java
// APJ
PageRecherche pr = new PageRecherche(o, request, listeCrt, listeInt, 4, libEntete, libEntete.length);
pr.creerObjetPage(libEntete, new String[]{"dispo"});
out.println(pr.getTableau().getHtml());
```
```jsp
<%-- Sans APJ --%>
<table>
  <tr><th>Id</th><th>Lot</th><th>Vivants</th></tr>
<%  double total = 0;
    ResultSet rs = stmt.executeQuery("select id, idlot, dispo from TRIAGEBATIMENTPARQUET_LIB where 1<2 " + criteres);
    while (rs.next()) { total += rs.getDouble("dispo"); %>
  <tr><td><a href="module.jsp?but=...-fiche.jsp&id=<%=rs.getString("id")%>"><%=rs.getString("id")%></a></td>
      <td><%=rs.getString("idlot")%></td><td><%=rs.getDouble("dispo")%></td></tr>
<%  } %>
  <tr><td colspan="2">Total</td><td><%= total %></td></tr>   <%-- = colSomme --%>
</table>
<%-- + les critères de recherche et la pagination : APJ les fait aussi --%>
```

## 7.2 Côté métier (Java) : APJ → Java / SQL classique

Les requêtes SQL ci-dessous sont **les vraies**, lues dans le log WildFly.

### La classe = la table
```java
// APJ
public class ReceptionUsine extends ClassMere {
    private String id, idlot, remarque;
    private java.sql.Date daty;
    private double qterecus;
    public ReceptionUsine() throws Exception { super.setNomTable("RECEPTIONUSINE"); }
}
```
```sql
-- Équivalent : la table qu'elle représente
CREATE TABLE RECEPTIONUSINE (
  id VARCHAR2(100) PRIMARY KEY, idlot VARCHAR2(100), daty DATE,
  qterecus NUMBER, remarque VARCHAR2(500), etat NUMBER );
```

### Fabriquer la clé
```java
// APJ
this.preparePk("RUI", "GETSEQRECEPTIONUSINE");
this.setId(makePK(c));                         // → "RUI000001"
```
```java
// Sans APJ
ResultSet rs = c.createStatement().executeQuery("select GETSEQRECEPTIONUSINE from dual");
rs.next();
String id = "RUI" + String.format("%06d", rs.getInt(1));
```

### Enregistrer (INSERT)
```java
// APJ
super.createObject(u, c);
```
```sql
-- Ce qu'APJ exécute (log réel : ta réception usine)
INSERT INTO RECEPTIONUSINE ( id , idlot , daty , heuredepart , heurearrive , qterecus , ...
       , remarque , etat )
values ( 'RUI000001','LOT000008','08/10/2026','02:32','04:32',8000.0, ... ,'test',1 )
```
```java
// Sans APJ : à écrire à la main, pour CHAQUE table
PreparedStatement ps = c.prepareStatement(
    "insert into RECEPTIONUSINE (id, idlot, daty, qterecus, remarque, etat) values (?,?,?,?,?,1)");
ps.setString(1, id);  ps.setString(2, idlot);  ps.setDate(3, daty);
ps.setDouble(4, qterecus);  ps.setString(5, remarque);
ps.executeUpdate();
```
> APJ construit la liste des colonnes à partir des **attributs** de la classe :
> un attribut en plus = une colonne en plus dans l'`INSERT`, automatiquement.

### Chercher (SELECT)
```java
// APJ
Lot[] lots = (Lot[]) CGenUtil.rechercher(new Lot(), null, null, " and idbc = 'BC001210'");
```
```sql
-- Ce qu'APJ exécute (forme réelle, vue dans le log)
select * from LOT where 1<2  and idbc = 'BC001210'
```
```java
// Sans APJ
List<Lot> lots = new ArrayList<>();
ResultSet rs = c.createStatement().executeQuery("select * from LOT where idbc = 'BC001210'");
while (rs.next()) {
    Lot l = new Lot();
    l.setId(rs.getString("id"));
    l.setNomlot(rs.getString("nomlot"));
    // ... un set par colonne
    lots.add(l);
}
```
> Le `where 1<2` est un truc d'APJ : une condition toujours vraie, pour pouvoir coller
> ensuite `and ...`. C'est pour ça que tes filtres commencent **toujours** par `" and "`.

### Une seule valeur
```java
// APJ
Object o = CGenUtil.rechercherSimple(
    "select nvl(sum(qte),0) from RECEPTIONUSINEDETAIL where idmere='RUI000001'", c);
```
```java
// Sans APJ
ResultSet rs = c.createStatement().executeQuery("select nvl(sum(qte),0) from ...");
rs.next();
double total = rs.getDouble(1);
```

### Modifier (UPDATE) et valider
```java
// APJ
u.updateObject(objet);          // modifier
u.validerObject(objet);         // valider (bouton « Valider » de la fiche)
```
```sql
-- Ce qu'APJ exécute à la validation (log réel : ton triage)
UPDATE TRIAGEBATIMENTPARQUET SET id='TB000007', daty='10/10/2026', idlot='LOT000008',
       dispomale=0, dispofemelle=0, etat=11, dispo=8000.0  WHERE id = 'TB000007'
```
> Valider = réécrire **toutes** les colonnes avec `etat = 11`. C'est pour ça que
> `validerObject` recharge d'abord l'enregistrement depuis la base (sinon il écrirait des vides).

### Les lignes d'un document
```java
// APJ
TriageBatimentParquetDetail[] lignes = (TriageBatimentParquetDetail[]) this.getFille();
```
```sql
-- Sans APJ
select * from TRIAGEBATIMENTPARQUETDETAIL where idmere = 'TB000007'
```

### Un contrôle
```java
// APJ : on lance une exception ; APJ annule tout et affiche le message
if (d.getQte() <= 0) throw new Exception("La quantité doit être supérieure à 0.");
```
```java
// Sans APJ : il faut gérer la transaction et le message soi-même
c.setAutoCommit(false);
try {
    if (qte <= 0) throw new Exception("La quantité doit être supérieure à 0.");
    // ... inserts ...
    c.commit();
} catch (Exception e) {
    c.rollback();
    request.setAttribute("erreur", e.getMessage());
    request.getRequestDispatcher("saisie.jsp").forward(request, response);
}
```
> Dans APJ, la transaction, le `rollback` et l'alerte à l'écran sont **déjà faits** par
> `apresMultiple.jsp` : toi, tu écris seulement `throw new Exception("message")`.

## 7.3 Le résumé en une table

| Je veux… | APJ (ce que tu écris) | Ce qu'APJ fait pour toi |
|---|---|---|
| un input | un attribut `private` + getter / setter | `<input name="attribut">` |
| un libellé | `setLibelle("...")` | `<label>...</label>` |
| cacher | `setVisible(false)` | `<input type="hidden">` |
| un select | `new Liste(...)` + `changerEnChamp` | `<select><option>...` + le `select` SQL |
| enregistrer | rien (le formulaire poste vers `apresMultiple.jsp`) | `INSERT` + transaction + redirection |
| chercher | `CGenUtil.rechercher(obj, null, null, " and ...")` | `select * from TABLE where 1<2 and ...` + remplissage des objets |
| une liste à l'écran | `PageRecherche` | `<table>` + critères + pagination + totaux |
| un contrôle | `throw new Exception("...")` | `rollback` + alerte à l'écran |
| valider | bouton « Valider » | `UPDATE ... SET etat = 11` |

---

**Où sont notées toutes les modifications du projet ?** → `_archive_aleas/sql/alea1_jeu_essai.md` (archivé avec les aléas)
(une section par changement, avec la cause, la correction et ce qui reste à vérifier).
