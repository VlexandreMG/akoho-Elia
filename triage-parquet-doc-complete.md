# Triage lot → parquet — documentation COMPLÈTE ligne par ligne

Périmètre : mettre les animaux d'un LOT dans des PARQUETs.
Dossier affichage : `arbiochem-war/web/pages/ferme/triagebatiment/`
Dossier métier : `arbiochem-ejb/src/java/ferme/triageBatiment/`
Base : dump `arbiochemstandard_20261002_160451.dmp`.

Rappel du circuit :

```
SAISIE (saisie.jsp) ──POST──► ACTION (apresMultiple.jsp, acte=insert)
──► MÉTIER (TriageBatimentParquet.createObject + filles)
──► BASE (TRIAGEBATIMENTPARQUET + TRIAGEBATIMENTPARQUETDETAIL)
──► FICHE (fiche.jsp) + LISTE (liste.jsp) + INC (det.jsp) pour relire
```

Conventions ci-dessous : chaque bout de code est recopié tel quel, suivi de
`► RÔLE :` qui dit ce qu'il fait dans le workflow.

---

# COUCHE 1 — AFFICHAGE

## 1.1. `ferme/triagebatiment/triagebatimentparquet-saisie.jsp` (112 lignes)

C'est LE formulaire où l'on choisit le lot et où l'on répartit ses animaux.

### Imports (lignes 1-13)

```jsp
<%@ page pageEncoding="UTF-8" contentType="text/html; charset=UTF-8" %>
<%@ page import="affichage.PageInsertMultiple"%>
<%@ page import="user.UserEJB" %>
<%@ page import="ferme.triageBatiment.TriageBatimentParquet" %>
<%@ page import="ferme.triageBatiment.TriageBatimentParquetDetail" %>
<%@ page import="affichage.Champ" %>
<%@ page import="affichage.Liste" %>
<%@ page import="bean.TypeObjet" %>
<%@ page import="ferme.configuration.Parquet" %>
<%@ page import="ferme.utils.ConstanteFerme" %>
<%@ page import="ferme.configuration.Batiment" %>
<%@ page import="ferme.configuration.ParquetBatiment" %>
<%@ page import="ferme.configuration.QualitePoussin" %>
```
► RÔLE : charge le framework de saisie multiple (`PageInsertMultiple`),
l'utilisateur connecté, les 2 classes métier (mère + fille), les briques de
champs (`Champ`, `Liste`, `TypeObjet`) et les 4 référentiels lus par le
formulaire : parquets, constantes ferme (sexes, qualité conforme),
bâtiments, couple parquet-bâtiment, qualités poussin.

### Constantes de navigation (lignes 15-23)

```jsp
<% try{
    UserEJB u = (user.UserEJB) session.getValue("u");
    String classeMere = "ferme.triageBatiment.TriageBatimentParquet";
    String classeFille = "ferme.triageBatiment.TriageBatimentParquetDetail";
    String nomTableFille = "TRIAGEBATIMENTPARQUETDETAIL";
    String colonneMere = "idmere";
    String apres = "ferme/triagebatiment/triagebatimentparquet-fiche.jsp";

    String idLot = request.getParameter("idLot");
```
► RÔLE : `u` = qui saisit (droits + connexion). Les 5 `String` sont les
paramètres cachés du POST : quelle classe insérer (mère/fille), dans quelle
table vont les lignes, par quelle colonne les lignes se rattachent à la mère
(`idmere`), et quelle fiche afficher après (`apres`). `idLot` = le lot
pré-sélectionné si on vient d'une fiche lot (`?idLot=LOT...`), sinon `null`
(saisie libre).

### Construction mère/fille (lignes 25-31)

```jsp
    TriageBatimentParquet mere = new TriageBatimentParquet();
    mere.setNomTable("TRIAGEBATIMENTPARQUET");
    TriageBatimentParquetDetail fille = new TriageBatimentParquetDetail();
    fille.setNomTable("TRIAGEBATIMENTPARQUETDETAIL");
    int taille = 10;
    PageInsertMultiple pi = new PageInsertMultiple(mere, fille, request, taille, u);
    pi.setLien((String) session.getValue("lien"));
    pi.setTitre("Saisie triage batiment par parquet");
```
► RÔLE : instancie les 2 objets métier sur leurs tables, demande un
formulaire à 10 lignes (`taille`), donne l'URL de base (`module.jsp`) et le
titre. `PageInsertMultiple` génère : le formulaire mère (date, lot, dispos)
+ le tableau des 10 lignes filles.

### Champs mère (lignes 35-50) — le cœur lot → dispo

```jsp
    pi.getFormu().getChamp("daty").setLibelle("Date");
    pi.getFormu().getChamp("idlot").setLibelle("lot");
    pi.getFormu().getChamp("etat").setVisible(false);
    pi.getFormu().getChamp("dispomale").setLibelle("M&acirc;les disponibles");
    pi.getFormu().getChamp("dispofemelle").setLibelle("Femelles disponibles");
    pi.getFormu().getChamp("idlot").setPageAppelComplete("ferme.lot.Lot","id","LOT","id","id");
    if(idLot != null && !idLot.isEmpty()){
        pi.getFormu().getChamp("idlot").setDefaut(idLot);
        pi.getFormu().getChamp("idlot").setAutre("readonly");
        double femelleDispo= mere.getDisponnibleLib(idLot,ConstanteFerme.IDSEXEFEMELLE, ConstanteFerme.qualiteConforme,null);
        double maleDispo= mere.getDisponnibleLib(idLot,ConstanteFerme.IDSEXEMALE,ConstanteFerme.qualiteConforme,null);
        pi.getFormu().getChamp("dispomale").setDefaut(Double.toString(maleDispo));
        pi.getFormu().getChamp("dispofemelle").setDefaut(Double.toString(femelleDispo));
        pi.getFormu().getChamp("dispomale").setAutre("readonly");
        pi.getFormu().getChamp("dispofemelle").setAutre("readonly");
    }
```
► RÔLE ligne par ligne :
- `daty` → date du tri ; `idlot` → quel lot on trie (autocomplete sur la
  table `LOT`, `setPageAppelComplete`) ; `etat` caché (mis par le workflow).
- `dispomale/dispofemelle` → rappels d'info, pas des stocks à saisir.
- Si `?idLot=` reçu : le lot est pré-rempli ET bloqué (`readonly`), puis le
  métier interroge la **vue** `v_qte_dispo_lot_sexe_qualite` pour les mâles
  (`IDSEXEMALE="1"`) et femelles (`IDSEXEFEMELLE="0"`) de qualité conforme
  (`QP000001`), et affiche les deux disponibles en `readonly`.
- C'est ici que « choisir le lot » pilote tout : sans lot, pas de dispos.

### Listes des lignes (lignes 53-76) — le « où » (parquet)

```jsp
    Liste[] liste = new Liste[4];
    TypeObjet sexe = new TypeObjet();
    sexe.setNomTable("SEXE");
    liste[0] = new Liste("idsexe", sexe, "val", "id");
    ParquetBatiment parquet = new ParquetBatiment();
    liste[2] = new Liste("idparquet", parquet, "val", "id");
    liste[1] = new Liste("idbatiment", new Batiment(), "nomBatiment", "id");
    liste[1].setDeroulanteDependante(liste[2],"idbatiment","onchange");
    QualitePoussin qualitePoussin = new QualitePoussin();
    liste[3] = new Liste("idqualite", qualitePoussin, "val", "id");
    pi.getFormufle().changerEnChamp(liste);
    pi.getFormufle().getChamp("idbatiment_0").setLibelle("B&acirc;timent");
    pi.getFormufle().getChamp("idparquet_0").setLibelle("Parquet");
    pi.getFormufle().getChamp("idsexe_0").setLibelle("Sexe");
    pi.getFormufle().getChamp("idqualite_0").setLibelle("Qualit&eacute;");
    pi.getFormufle().getChamp("qte_0").setLibelle("Quantit&eacute;");
    Champ.setVisible(pi.getFormufle().getChampMulitple("idmere").getListeChamp(),false);
//    Champ.setPageAppelComplete(pi.getFormufle().getChampFille("idbatiment"),"ferme.configuration.Batiment","id","BATIMENT","id","id");  (lignes 70-73 désactivées)
//    Champ.setPageAppelComplete(pi.getFormufle().getChampFille("idparquet"),"ferme.configuration.Parquet","id","PARQUET","id","id");
//    Champ.setPageAppelComplete(pi.getFormufle().getChampFille("idsexe"),"bean.TypeObjet","id","SEXE","id","val");
//    Champ.setPageAppelComplete(pi.getFormufle().getChampFille("idqualite"),"ferme.configuration.QualitePoussin","id","QUALITEPOUSSIN","id","id");
    String[] colOrdre = {"idbatiment","idparquet","idsexe","idqualite","qte"};
    pi.getFormufle().setColOrdre(colOrdre);
```
► RÔLE : les 4 zones texte des lignes deviennent des listes : sexe (`SEXE`),
bâtiment (`BATIMENT`), parquet (`PARQUET_BATIMENT_LIB`), qualité
(`QUALITEPOUSSIN`). Point clé : `setDeroulanteDependante` — la liste des
parquets se **filtre selon le bâtiment choisi** (`onchange`). `idmere` est
caché partout (rempli auto à l'insert). Les 4 lignes `setPageAppelComplete`
commentées sont l'ancien système remplacé par les listes. `colOrdre` fixe
l'ordre visible des colonnes : bâtiment → parquet → sexe → qualité → qte.

### Fin de préparation + HTML (lignes 78-103)

```jsp
    String acte = request.getParameter("acte");
    if(acte != null && acte.equalsIgnoreCase("update")){
        pi.setTitre("Modification triage batiment par parquet");
    }

    pi.preparerDataFormu();
    pi.getFormu().makeHtmlInsertTabIndex();
    pi.getFormufle().makeHtmlInsertTableauIndex();
%>
<div class="content-wrapper">
    <h1><%=pi.getTitre()%></h1>
    <form id="formId" class='container' action="<%=pi.getLien()%>?but=apresMultiple.jsp" method="post" >
        <%
            out.println(pi.getFormu().getHtmlInsert());
            out.println(pi.getFormufle().getHtmlTableauInsert());
        %>
        <input name="acte" type="hidden" id="nature" value="insert">
        <input name="bute" type="hidden" id="bute" value="<%=apres%>">
        <input name="classe" type="hidden" id="classe" value="<%=classeMere%>">
        <input name="classefille" type="hidden" id="classefille" value="<%=classeFille%>">
        <input name="nomtable" type="hidden" id="nomtable" value=<%=nomTableFille%>>
        <input name="nombreLigne" type="hidden" id="nombreLigne" value="<%=taille%>">
        <input name="colonneMere" type="hidden" id="colonneMere" value="<%=colonneMere%>">
    </form>
</div>
<% } catch (Exception e) {
  e.printStackTrace();
%>
<script language="JavaScript"> alert('<%=e.getMessage()%>'); history.back(); </script>
<% }%>
```
► RÔLE : si `?acte=update`, la même page sert à modifier (titre adapté).
`preparerDataFormu` charge les 4 listes depuis la base, les 2 `makeHtml...`
préparent le HTML. Le `<form>` POSTe vers `apresMultiple.jsp` ; les 7 hidden
sont le contrat avec l'ACTION : `acte=insert` (quoi faire),
`bute` (fiche après), `classe/classefille` (quoi insérer), `nomtable`
(où vont les lignes), `nombreLigne=10`, `colonneMere=idmere` (soudure).
Le `catch` loggue (`server.log`) + popup + retour arrière.

---

## 1.2. `ferme/triagebatiment/triagebatimentparquet-liste.jsp` (67 lignes)

C'est la liste de TOUS les tris (recherche + tableau + pagination).

### Ouverture (lignes 1-7)

```jsp
<%@ page pageEncoding="UTF-8" contentType="text/html; charset=UTF-8" %>
<%@ page import="affichage.PageRecherche"%>
<%@ page import="ferme.triageBatiment.TriageBatimentParquetLib" %>
<% try{
    TriageBatimentParquetLib o = new TriageBatimentParquetLib();
    o.setNomTable("TRIAGEBATIMENTPARQUET_LIB");
```
► RÔLE : page UTF-8, framework de recherche, modèle = la **vue**
`TRIAGEBATIMENTPARQUET_LIB` (mère + libellés lot/souche). Lecture seule :
cette page n'écrit jamais en base.

### Recherche (lignes 8-20)

```jsp
    String[] listeCrt = {"idLotLib","idSoucheLib","daty"};
    String[] listeInt = {"daty"};
    String[] libEntete = {"id","idLotLib","idSoucheLib","daty","dispomale","dispofemelle","etatlib"};
    PageRecherche pr = new PageRecherche(o, request, listeCrt, listeInt, 4, libEntete, libEntete.length);
    pr.setTitre("Liste des triage batiment par parquet");
    pr.setUtilisateur((user.UserEJB) session.getValue("u"));
    pr.setLien((String) session.getValue("lien"));
    pr.setApres("ferme/triagebatiment/triagebatimentparquet-liste.jsp");
    pr.getFormu().getChamp("idLotLib").setLibelle("Nom du lot");
    pr.getFormu().getChamp("idSoucheLib").setLibelle("Souche");
    pr.getFormu().getChamp("daty1").setLibelle("Date min");
    pr.getFormu().getChamp("daty2").setLibelle("Date max");
```
► RÔLE : critères = nom du lot, souche, intervalle de dates (`daty1/daty2`
générés par `listeInt`). Colonnes SQL affichées : id, lot, souche, date,
dispos, état. `setApres` = la page se re-soumet à elle-même (filtres).
Les libellés renomment les champs pour l'utilisateur.

### Récap + tableau + pagination (lignes 21-36)

```jsp
    String[] colSomme = {"dispomale","dispofemelle"};
    pr.creerObjetPage(libEntete, colSomme);
    pr.getTableau().setLienFille("ferme/triagebatiment/inc/triagebatimentparquet-det.jsp&id=");
    String[] enteteRecap = {"","Nombre","Somme des dispomales","Somme des dispofemelles"};
    pr.getTableauRecap().setLibeEntete(enteteRecap);
    String[] lienTableau = {pr.getLien() + "?but=ferme/triagebatiment/triagebatimentparquet-fiche.jsp"};
    String[] colonneLien = {"id"};
    String[] attributLien = {"id"};
    pr.getTableau().setLien(lienTableau);
    pr.getTableau().setColonneLien(colonneLien);
    pr.getTableau().setAttLien(attributLien);
    String[] libEnteteAffiche = {"Id","Nom du lot","Souche","Date","Dispo m&acirc;le","Dispo femelle","&Eacute;tat"};
    pr.getTableau().setLibelleAffiche(libEnteteAffiche);
```
► RÔLE : `creerObjetPage` exécute le SELECT paginé + totalise les dispos
(`colSomme` → récap « Nombre / Somme dispos »). `setLienFille` = chaque ligne
se déplie pour montrer ses parquets (détail, `id` ajouté en fin d'URL).
Clic sur `id` → fiche du tri. Titres visibles francisés.

### HTML (lignes 39-66)

```jsp
<div class="content-wrapper">
    <section class="content-header">
        <h1><%= pr.getTitre() %></h1>
    </section>
    <section class="content">
        <form action="<%=pr.getLien()%>?but=<%= pr.getApres() %>" method="post">
            <% out.println(pr.getFormu().getHtmlEnsemble()); %>
        </form>
        <% out.println(pr.getTableauRecap().getHtml()); %>
        <br>
        <% out.println(pr.getTableau().getHtml()); out.println(pr.getBasPage()); %>
    </section>
</div>
<% } catch (Exception e) { e.printStackTrace(); %>
<script language="JavaScript"> alert('<%=e.getMessage()%>'); history.back(); </script>
<% }%>
```
► RÔLE : titre, formulaire qui se re-soumet à la liste, récap, tableau,
pagination. `catch` = log + popup + retour.

---

## 1.3. `ferme/triagebatiment/triagebatimentparquet-fiche.jsp` (103 lignes)

C'est la carte d'UN tri : lot + souche + dispos + écarts + ses lignes.

### Chargement (lignes 1-16)

```jsp
<%@ page pageEncoding="UTF-8" contentType="text/html; charset=UTF-8" %>
<%@ page import="user.UserEJB" %>
<%@ page import="affichage.PageConsulte" %>
<%@ page import="ferme.triageBatiment.TriageBatimentParquetLib" %>
<%@ page import="java.util.HashMap" %>
<%@ page import="java.util.Map" %>
<%@page import="utilitaire.ConstanteEtat"%>
<% try{
    UserEJB u = (user.UserEJB)session.getValue("u");
    String lien = (String) session.getValue("lien");
    TriageBatimentParquetLib o = new TriageBatimentParquetLib();
    o.setNomTable("TRIAGEBATIMENTPARQUET_LIB");
    PageConsulte pc = new PageConsulte(o, request, u);
    pc.setTitre("Fiche triage batiment par parquet");
    String id = pc.getBase().getTuppleID();
```
► RÔLE : charge le tri demandé (`?id=TB...`) via la vue `..._LIB`
(libellés inclus) pour l'utilisateur connecté. `id` = le tri affiché.

### Champs (lignes 18-32)

```jsp
    pc.getChampByName("id").setLibelle("Id");
    pc.getChampByName("idLotLib").setLibelle("Nom du lot");
    pc.getChampByName("IdSoucheLib").setLibelle("Souche");
    pc.getChampByName("daty").setLibelle("Date");
    pc.getChampByName("etatLib").setLibelle("&Eacute;tat");
    pc.getChampByName("etat").setVisible(false);
    pc.getChampByName("idlot").setLibelle("ID Lot");
    pc.getChampByName("idlot").setLien(lien+"?but=ferme/lot/lot-fiche.jsp", "id=");
    pc.getChampByName("dispomale").setLibelle("Disponibilit&eacute; m&acirc;le");
    pc.getChampByName("dispofemelle").setLibelle("Disponibilit&eacute; femelle");
    pc.getChampByName("ecartFemelle").setLibelle("&Eacute;cart femele");
    pc.getChampByName("ecartMale").setLibelle("&Eacute;cart m&acirc;le");
    String[] ordre = {"id","idlot","idLotLib","IdSoucheLib","daty","dispomale","dispofemelle","ecartMale","ecartFemelle","etatLib"};
    pc.setOrdre(ordre);
```
► RÔLE : francise les libellés, cache le code `etat` (le libellé suffit),
rend `idlot` **cliquable vers la fiche du lot** (traçabilité lot → tri),
affiche les dispos + les **écarts** (dispo − trié, calculés par la vue).
`ordre` fixe l'ordre d'affichage des champs.

### Onglets + boutons (lignes 34-71)

```jsp
    String pageActuel = "ferme/triagebatiment/triagebatimentparquet-fiche.jsp";
    String pageRetour = "ferme/triagebatiment/triagebatimentparquet-liste.jsp";
    String pageModif = "ferme/triagebatiment/triagebatimentparquet-saisie.jsp&acte=update";
    String pageApresDelete = "ferme/triagebatiment/triagebatimentparquet-liste.jsp";
    String classe = "ferme.triageBatiment.TriageBatimentParquet";
    Map<String, String> map = new HashMap<>();
    map.put("inc/triagebatimentparquet-det", "");
    String tab = request.getParameter("tab");
    if (tab == null) { tab = "inc/triagebatimentparquet-det"; }
    map.put(tab, "active");
    tab = tab + ".jsp";
    TriageBatimentParquetLib base = (TriageBatimentParquetLib)pc.getBase();
```
► RÔLE : mémorise les 4 pages du cycle (fiche, retour liste, modif,
après-suppression) + la classe pour les actions. Un seul onglet :
le détail des lignes, actif par défaut.

```jsp
<h1 class="box-title"><a href=<%= lien + "?but=" + pageRetour%>> <i class="fa fa-angle-left"></i></a><%=pc.getTitre()%></h1>
<% out.println(pc.getHtml()); %>
<% if(base.getEtat() < ConstanteEtat.getEtatValider()) { %>
<a class="btn btn-primary pull-right" href="<%= lien + "?but=apresTarif.jsp&id=" + id+"&acte=valider&bute="+pageActuel+"&classe="+classe %>">Valider</a>
<a class="btn btn-secondary pull-right" href="<%= lien + "?but="+ pageModif +"&id=" + id %>" style="margin-right: 10px">Modifier</a>
<a class="btn btn-danger pull-left" href="<%= lien + "?but=apresTarif.jsp&id=" + id+"&acte=delete&bute="+pageApresDelete+"&classe="+classe %>">Supprimer</a>
<% } %>
```
► RÔLE : flèche retour + carte du tri. Si non validé : **Valider**
(`apresTarif.jsp?acte=valider` → état 11), **Modifier** (saisie en update),
**Supprimer** (`acte=delete` → retour liste). Une fois validé, plus de
boutons : le tri est figé.

### Onglet détail (lignes 79-95)

```jsp
<ul class="nav nav-tabs">
    <li class="<%=map.get("inc/triagebatimentparquet-det")%>"><a href="<%= lien %>?but=<%= pageActuel %>&id=<%= id %>&tab=inc/triagebatimentparquet-det">D&eacute;tails</a></li>
</ul>
<div class="tab-content">
        <jsp:include page="<%= tab %>" >
            <jsp:param name="id" value="<%= id %>" />
        </jsp:include>
</div>
<% } catch (Exception e) { e.printStackTrace(); %>
<script language="JavaScript"> alert('<%=e.getMessage()%>'); history.back(); </script>
<% }%>
```
► RÔLE : l'onglet inclut la page détail en lui passant `id` (= `idmere`
des lignes). `catch` = log + popup + retour.

---

## 1.4. `ferme/triagebatiment/inc/triagebatimentparquet-det.jsp` (44 lignes)

C'est le tableau des lignes d'UN tri (ou d'UN lot).

```jsp
<%@ page pageEncoding="UTF-8" contentType="text/html; charset=UTF-8" %>
<%@ page import="affichage.PageRecherche"%>
<%@ page import="ferme.triageBatiment.TriageBatimentParquetDetailLib" %>
<% try{
    TriageBatimentParquetDetailLib o = new TriageBatimentParquetDetailLib();
    o.setNomTable("TRIAGEBATPARQUETDETAIL_LIB");
    String[] listeCrt = {};
    String[] listeInt = {};
    String[] libEntete = {"idBatimentLib","idParquetLib","idQualiteLib","idSexeLib","qte"};
    PageRecherche pr = new PageRecherche(o, request, listeCrt, listeInt, 4, libEntete, libEntete.length);
    pr.setUtilisateur((user.UserEJB) session.getValue("u"));
    pr.setLien((String) session.getValue("lien"));

    if(request.getParameter("id") != null && request.getParameter("isLot")==null){
        pr.setAWhere(" and idmere='"+request.getParameter("id")+"'");
    }
    else if(request.getParameter("id") != null && request.getParameter("isLot")!=null){
        pr.setAWhere(" and idlot='"+request.getParameter("id")+"'");
    }
    String[] colSomme = null;
    pr.creerObjetPage(libEntete, colSomme);
    String[] libEnteteAffiche = {"B&acirc;timent","Parquet","Qualit&eacute;","Sexe","Quantit&eacute;"};
    pr.getTableau().setLibelleAffiche(libEnteteAffiche);
%>
<div class="box-body">
    <%  if(pr.getTableau().getHtml() != null){
            out.println(pr.getTableau().getHtml());
        } else{ %>
            <center><h4>Aucune donn&eacute;e trouv&eacute;e</h4></center>
    <%  } %>
</div>
<% } catch (Exception e) { e.printStackTrace(); %>
<script language="JavaScript"> alert('<%=e.getMessage()%>'); history.back(); </script>
<% }%>
```
► RÔLE : aucun critère saisi (`listeCrt` vide) : le filtre vient de l'URL.
Deux modes : `?id=TB...` (sans `isLot`) → lignes de CE tri
(`and idmere=...`) ; `?id=LOT...&isLot=1` → TOUTES les lignes issues de CE
lot (`and idlot=...`, la vue détail expose aussi le lot). D'où le double
usage : onglet de la fiche tri + (réutilisable) onglet de la fiche lot.
Si rien : message « Aucune donnée trouvée » au lieu d'un tableau vide.

---

# COUCHE 2 — ACTION (`web/pages/apresMultiple.jsp`, branche `acte=insert`)

Page **générique partagée** par tout le projet (BC, BL, tri, factures...).
Seule la branche `insert` nous concerne : c'est elle qui reçoit le POST de
la saisie tri.

### Lecture des hidden (extraits commentés du fichier)

```jsp
ben = request.getParameter("nomtable");            // "TRIAGEBATIMENTPARQUETDETAIL"
typeBoutton = request.getParameter("type");
lien = (String) session.getValue("lien");          // module.jsp
u = (UserEJB) session.getAttribute("u");           // qui insère
acte = request.getParameter("acte");               // "insert"
bute = request.getParameter("bute");               // fiche tri après
String classe = request.getParameter("classe");    // "ferme.triageBatiment.TriageBatimentParquet"
String classefille = request.getParameter("classefille"); // "...TriageBatimentParquetDetail"
String colonneMere = request.getParameter("colonneMere"); // "idmere"
int nbLine = Utilitaire.stringToInt(request.getParameter("nombreLigne")); // 10
```
► RÔLE : récupère les 7 hidden + utilisateur + lien. Chaque hidden a un
consommateur précis plus bas ; si l'un manque ou est faux, l'insert échoue
(table inconnue, classe introuvable, soudure cassée).

### Branche insert (lignes ~134-150 du fichier commenté)

```jsp
if (acte != null && acte.compareToIgnoreCase("insert") == 0) {
    mere = (ClassMAPTable) (Class.forName(classe).newInstance());
    fille = (ClassMAPTable) (Class.forName(classefille).newInstance());
    PageInsertMultiple p = new PageInsertMultiple(mere, fille, request, nbLine, tId);
    ClassMAPTable cmere = p.getObjectAvecValeur();
    ClassMAPTable[] cfille = p.getObjectFilleAvecValeur();
    for (int i = 0; i < cfille.length; i++) {
        cfille[i].setNomTable(nomtable);
    }
    ClassMAPTable o = (ClassMAPTable) u.createObjectMultiple(cmere, colonneMere, cfille);
    temp = (Object) o;
    if (temp != null) {
        val = temp.toString();
        idmere = o.getTuppleID();
    }%>
<script language="JavaScript"> document.location.replace("<%=lien%>?but=<%=bute%>&id=<%=idmere%>");</script>
<% }
```
► RÔLE ligne par ligne :
- `Class.forName(classe).newInstance()` → recrée la mère à partir de son
  NOM (pas d'import direct : générique).
- `new PageInsertMultiple(mere, fille, request, nbLine, tId)` → relit les
  10 lignes du formulaire.
- `getObjectAvecValeur()` → mère remplie (date, lot, dispos).
- `getObjectFilleAvecValeur()` → lignes remplies **AVEC contrôles** (≠
  `...SansControle`) : ignore les lignes vides, convertit les types.
- boucle `setNomTable(nomtable)` → chaque ligne sait qu'elle va dans
  `TRIAGEBATIMENTPARQUETDETAIL`.
- `u.createObjectMultiple(cmere, "idmere", cfille)` → **le vrai INSERT** :
  PK mère (`TB...`), INSERT mère, recopie `idmere` sur chaque fille, PK
  filles (`TBD...`), INSERT filles, le tout en transaction EJB.
- `idmere = o.getTuppleID()` → l'id du tri créé.
- redirection JS → **la fiche du tri créé** (`bute&id=TB...`).

### Règle d'or de la couche ACTION
► Ne JAMAIS modifier `apresMultiple.jsp` pour un besoin du tri : elle sert
à tout le projet. Besoin spécial → métier (`createObject` de l'entité) ou
page d'action dédiée.

---

# COUCHE 3 — MÉTIER (`arbiochem-ejb/src/java/ferme/triageBatiment/`)

## 3.1. `TriageBatimentParquet.java` (175 lignes) — la mère

### Champs (lignes 12-65)

```java
public class TriageBatimentParquet extends ClassMere {
    private String id;
    private Date daty;
    private String idlot;
    private int dispomale;
    private int dispofemelle,etat;
    // + getters/setters getId/setId, getDaty/setDaty, getIdlot/setIdlot,
    //   getEtat/setEtat, getDispomale/setDispomale, getDispofemelle/setDispofemelle
```
► RÔLE : `ClassMere` = sait porter des filles. `id` = PK (`TB...`).
`daty` = date du tri. `idlot` = **LE lot trié** (le « qui »).
`dispomale/dispofemelle` = photo des dispos au moment du tri (info,
recopiée du calcul, pas recalculée après). `etat` = workflow
(1 créé → 11 validé). Getters/setters = accès lus par le framework
pour remplir/lire chaque champ.

### Constructeur + PK (lignes 69-89)

```java
    public TriageBatimentParquet() throws Exception {
        this.setNomTable("TRIAGEBATIMENTPARQUET");
        this.setNomClasseFille("ferme.tirageBatiment.TriageBatimentParquetDetail");
        this.setLiaisonFille("idmere");
    }

    @Override
    public void construirePK(Connection c) throws Exception {
        this.preparePk("TB","getseq_triagebatimentparquet");
        this.setId(makePK(c));
    }

    @Override
    public String getTuppleID() {
        return id;
    }

    @Override
    public String getAttributIDName() {
        return "id";
    }
```
► RÔLE : le constructeur soude la mère à sa table + déclare sa classe
fille et la colonne de liaison (`idmere`) — les mêmes valeurs que les
hidden `classe/classefille/colonneMere` du POST. `construirePK` fabrique
l'id `TB...` via la séquence. `getTuppleID/getAttributIDName` disent au
framework quel champ est la PK (`id`). ⚠️ coquille d'origine à connaître :
`ferme.tirageBatiment` (avec un seul `i`) dans `setNomClasseFille`
ligne 71 — ne pas « corriger » sans tester, le framework peut s'en servir.

### createObject — contrôle désactivé (lignes 91-124)

```java
    @Override
    public ClassMAPTable createObject(String u, Connection c) throws Exception {
//        TriageBatimentParquetDetail[] triageBatimentParquetDetails = (TriageBatimentParquetDetail[]) this.getFille();
//        double quantiteMale = this.getDispomale();
//        double quantiteFemelle = this.getDispofemelle();
//        double sommeMale = 0;
//        double sommeFemelle = 0;
//        for (int i = 0; i < triageBatimentParquetDetails.length; i++) {
//            String idsexe = triageBatimentParquetDetails[i].getIdsexe();
//            double qte = triageBatimentParquetDetails[i].getQte();
//            if (ConstanteFerme.IDSEXEMALE.equals(idsexe)) {
//                sommeMale += qte;
//            } else if (ConstanteFerme.IDSEXEFEMELLE.equals(idsexe)) {
//                sommeFemelle += qte;
//            } else {
//                throw new Exception("Sexe non reconnu pour la ligne de détail: " + idsexe);
//            }
//        }
//        if (sommeMale != quantiteMale) {
//            throw new Exception("La quantité totale des mâles triés (" + sommeMale
//                    + ") ne correspond pas à la quantité disponible male (" + quantiteMale + ")");
//        }
//        if (sommeFemelle != quantiteFemelle) {
//            throw new Exception("La quantité totale des femelles triées (" + sommeFemelle
//                    + ") ne correspond pas à la quantité disponible femelle (" + quantiteFemelle + ")");
//        }
        return super.createObject(u, c);
    }
```
► RÔLE : aujourd'hui seule la dernière ligne vit → INSERT direct sans
contrôle. Le bloc commenté = LA règle métier en attente : total des lignes
mâles doit égaler `dispomale`, idem femelles, sinon `Exception` (affichée
en popup par la saisie + retour arrière). Pour l'activer : décommenter
(et durcir `!=` en comparaison avec tolérance si besoin).

### Disponibles (lignes 125-173)

```java
    public double getDisponnible(String idLot,String idSexe,Connection c)throws Exception{
        boolean canClose=false;
        try{
            if(c==null){
                c=new UtilDB().GetConn();
                canClose=true;
            }
            TriageLotSexeQualite t = new TriageLotSexeQualite();
            t.setIdLot(idLot);
            t.setIdsexe(idSexe);
            t.setIdqualite(ConstanteFerme.qualiteConforme);
            TriageLotSexeQualite[] r = (TriageLotSexeQualite[])CGenUtil.rechercher(t, null, null, c, "");
            if(r.length>0 && r!=null){
                return r[0].getQte();
            }
            return 0;
        } catch(Exception e){
            throw e;
        } finally {
            if(canClose){
                c.close();
            }
        }
    }
```
► RÔLE : dispo d'un (lot, sexe) en qualité conforme : ouvre une connexion
si besoin (`canClose`), cherche dans la vue, rend la qte ou `0`, referme.
`getDisponnibleLib` (lignes 150-173) = même chose + filtre qualité libre —
c'est ELLE qu'appelle la saisie (lignes 44-45).

## 3.2. `TriageBatimentParquetDetail.java` (104 lignes) — la fille

```java
package ferme.triageBatiment;

import bean.ClassFille;
import java.sql.Connection;

public class TriageBatimentParquetDetail extends ClassFille {
    private String id;
    private String idmere;
    private String idbatiment;
    private String idparquet;
    private String idsexe;
    private String idqualite;
    private int qte;
    // + getters/setters pour les 7 champs (lignes 15-69)

    @Override
    public String getNomClasseMere() {
        return "ferme.tirageBatiment.TriageBatimentParquet";
    }

    @Override
    public String getLiaisonMere() {
        return "idmere";
    }

    public TriageBatimentParquetDetail() throws Exception {
        this.setNomTable("TRIAGEBATIMENTPARQUETDETAIL");
        this.setNomClasseMere("ferme.tirageBatiment.TriageBatimentParquet");
        this.setLiaisonMere("idmere");
    }

    @Override
    public void construirePK(Connection c) throws Exception {
        this.preparePk("TBD","getseq_triagebatparquetdetail");
        this.setId(makePK(c));
    }

    @Override
    public String getTuppleID() {
        return id;
    }

    @Override
    public String getAttributIDName() {
        return "id";
    }
```
► RÔLE : `ClassFille` = sait se rattacher à une mère. Les 7 champs sont
les 7 colonnes de la table (recopiées telles quelles §4.1). `idmere` =
soudure (remplie auto par `createObjectMultiple`). `idbatiment/idparquet`
= le « où », `idsexe/idqualite/qte` = quoi/combien. PK `TBD...`. ⚠️ même
coquille `tirageBatiment` qu'en 3.1 : les 2 doivent rester cohérentes
entre elles, ne toucher ni l'une ni l'autre.

## 3.3. `TriageLotSexeQualite.java` — la vue des disponibles

```java
package ferme.triageBatiment;

import bean.ClassMAPTable;

public class TriageLotSexeQualite extends TriageBatimentParquetDetail {
    private String idLot;
    public TriageLotSexeQualite() throws Exception {
        this.setNomTable("v_qte_dispo_lot_sexe_qualite");
    }

    public String getIdLot() {
        return idLot;
    }

    public void setIdLot(String idLot) {
        this.idLot = idLot;
    }
```
► RÔLE : hérite de la fille (donc a `idsexe`, `idqualite`, `qte`) mais lit
la **vue** `v_qte_dispo_lot_sexe_qualite` au lieu de la table : elle rend,
par (lot, sexe, qualité), la quantité encore disponible au tri. `idLot`
(avec L majuscule) = critère de recherche posé par `getDisponnible(Lib)`.
`TriageLotSexeQualiteLib` = même vue + libellés. Si les dispos affichés
sont faux, c'est CETTE vue SQL qu'il faut auditer en premier.

## 3.4. `ferme.utils.ConstanteFerme.java` (extraits) + classes Lib

```java
public static String IDSEXEMALE = "1";
public static String IDSEXEFEMELLE = "0";
public static String qualiteConforme = "QP000001";
```
► RÔLE : `"1"` = mâle, `"0"` = femelle (codes table `SEXE`) ;
`"QP000001"` = la qualité « conforme » (table `QUALITEPOUSSIN`). Ce sont
les 3 codes magiques utilisés par la saisie (`getDisponnibleLib`) et par
le contrôle commenté. Les changer = changer le sens du tri partout.

```java
// TriageBatimentParquetLib :  this.setNomTable("TRIAGEBATIMENTPARQUET_LIB");
// TriageBatimentParquetDetailLib : vue "TRIAGEBATPARQUETDETAIL_LIB"
```
► RÔLE : classes de lecture (jamais d'INSERT) : mère + libellés lot/souche
et écarts (`ecartMale/ecartFemelle` = dispo − trié) pour la fiche/liste ;
détail + libellés bâtiment/parquet/sexe/qualité pour l'onglet.

---

# COUCHE 4 — BASE (dump `arbiochemstandard_20261002_160451.dmp`)

## 4.1. DDL réel (extrait du dump, recopié tel quel)

```sql
CREATE TABLE "TRIAGEBATIMENTPARQUET"
  ("ID" VARCHAR2(100), "DATY" DATE, "IDLOT" VARCHAR2(100),
   "DISPOMALE" NUMBER, "DISPOFEMELLE" NUMBER, "ETAT" NUMBER(*,0));

CREATE TABLE "TRIAGEBATIMENTPARQUETDETAIL"
  ("ID" VARCHAR2(100), "IDMERE" VARCHAR2(100),
   "IDBATIMENT" VARCHAR2(100), "IDPARQUET" VARCHAR2(100),
   "IDSEXE" VARCHAR2(100), "IDQUALITE" VARCHAR2(100), "QTE" NUMBER);
```
► RÔLE : 6 colonnes mère (`ID` PK, date, lot trié, 2 dispos photo, état
workflow) ; 7 colonnes fille (`ID` PK, `IDMERE` soudure, bâtiment, parquet,
sexe, qualité, quantité). Chaque champ Java de 3.1/3.2 correspond à une
colonne ici, **dans le même nom** : ajouter une colonne sans ajouter le
champ Java (ou l'inverse) casse l'insert.

## 4.2. Clés, séquences, vues, référentiels

```sql
-- PK : "ID" des 2 tables.
-- Liaison : DETAIL.IDMERE → mère. Contraintes nommées dans le dump :
"FK_TRIAGEDETAIL_BATIMENT" "_MERE" "_PARQUET" "_QUALITE"
-- Côté lot : "FK_TRIAGEPOUS_LOT" (+ "FK_TRANSFPOULET_LOT", "FK_RECPOUSS_LOT").
-- Séquences : "getseq_triagebatimentparquet" (mère TB...),
--             "getseq_triagebatparquetdetail" (filles TBD...).
```
► RÔLE : les FK garantissent qu'on ne trie pas vers un bâtiment/parquet/
qualité inexistant ; la FK lot garantit un lot réel. Les séquences
fabriquent les ids (`preparePk("TB"/"TBD", ...)` côté métier).
- Vues lues : `TRIAGEBATIMENTPARQUET_LIB`,
  `TRIAGEBATPARQUETDETAIL_LIB`, `v_qte_dispo_lot_sexe_qualite`.
- Référentiels : `LOT` (+ `SOUCHE` via `LOT.idSouche`), `PARQUET`,
  `BATIMENT`, `SEXE`, `QUALITEPOUSSIN`.
- Règle d'or : **jamais d'ALTER/DROP à la main** — DDL, PK, FK,
  séquences = contrat partagé avec le métier ; toute évolution = migration
  + champ Java + saisie, testés ensemble (insert → fiche).

---

# 5. CUISINE — si on me demande de changer quelque chose

| On me demande... | Couche + fichiers | Comment faire |
|---|---|---|
| Changer un libellé / l'ordre des colonnes / 10 lignes | 1 (saisie `setLibelle`, `colOrdre`, `taille`) | Recharger, vérifier le POST (onglet Réseau). Zéro risque base. |
| Filtrer les parquets (ex. actifs seulement) | 1 (saisie `liste[2].setApresW(...)`) | Comme `MAGASIN2` côté BC (`and actif = 1`). Tester avec 2 bâtiments. |
| Pré-remplir autre chose depuis `?idLot=` | 1 (saisie lignes 41-50) | `getDefaut` + `readonly` sur le modèle de 44-49. |
| Contrôler qte ≤ dispo (LA règle) | 3 (`createObject` 3.1, décommenter) | `throw new Exception("message clair")` → popup + `history.back()`. Vérifier `server.log`. Durcir `!=` si arrondis. |
| Changer la source du dispo | 3 (`getDisponnibleLib`) + 4 (vue `v_qte_dispo...`) | Vue SQL d'abord, méthode ensuite. Jamais l'un sans l'autre. |
| Ajouter une colonne (ex. remarque ligne) | 4 → 3 → 1, **dans cet ordre** | 1) migration `ALTER TABLE ...DETAIL ADD`, 2) champ + getter/setter dans `Detail`, 3) `colOrdre`/libellé saisie. Tester insert → fiche. |
| Changer la redirection après insert | 1 (hidden `bute`) | Autre fiche/liste. Ne pas toucher l'ACTION. |
| Valider / supprimer un tri | Rien à coder (boutons fiche → `apresTarif`) | Vérifier `etat`, `classe`, `bute` dans l'URL du bouton. |
| Insert qui échoue (page blanche / popup) | `server.log` WildFly + alerte | `NullPointer` = champ mal nommé ; violation FK = lot/parquet inexistant ; `TB/TBD` en double = séquence. |
