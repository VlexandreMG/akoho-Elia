<%@page import="ferme.receptionusine.*"%>
<%@page import="ferme.utils.ConstanteFerme"%>
<%@page import="ferme.configuration.QualitePoussin"%>
<%@page import="user.UserEJB"%>
<%@page import="affichage.PageInsertMultiple"%>
<%@page import="affichage.Liste"%>
<%@page import="bean.TypeObjet"%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%
try {
    UserEJB u = (UserEJB) session.getValue("u");

    ReceptionUsine       mere  = new ReceptionUsine();
    ReceptionUsineDetail fille = new ReceptionUsineDetail();
    int nombreLigne = 10;

    PageInsertMultiple pi = new PageInsertMultiple(mere, fille, request, nombreLigne, u);
    pi.setLien((String) session.getValue("lien"));

    // ── EN-TÊTE : le lot (déjà reçu à l'aéroport) + le transport ──
    pi.getFormu().getChamp("idlot").setLibelle("Lot");
    pi.getFormu().getChamp("idlot").setPageAppelComplete("ferme.lot.Lot", "id", "LOT");
    pi.getFormu().getChamp("daty").setLibelle("Date");
    pi.getFormu().getChamp("heuredepart").setLibelle("Heure de d&eacute;part");
    pi.getFormu().getChamp("heuredepart").setType("time");
    pi.getFormu().getChamp("heurearrive").setLibelle("Heure d'arriv&eacute;e");
    pi.getFormu().getChamp("heurearrive").setType("time");
    pi.getFormu().getChamp("idvehicule").setLibelle("V&eacute;hicule");
    pi.getFormu().getChamp("idchauffeur").setLibelle("Chauffeur");
    pi.getFormu().getChamp("idcontroleur").setLibelle("Contr&ocirc;leur");
    pi.getFormu().getChamp("remarque").setLibelle("Remarque");

    // Calculés ou inutilisés à cette étape :
    //   qterecus = vivants = vivants aéroport - morts - perdus (calculé en Java)
    //   pas de sexe ni de cartons avant la répartition en parquets (0 par défaut)
    pi.getFormu().getChamp("etat").setVisible(false);
    pi.getFormu().getChamp("qterecus").setVisible(false);
   // pi.getFormu().getChamp("nbrcartonmale").setVisible(false);
   // pi.getFormu().getChamp("nbrcartonfemelle").setVisible(false);

    // ── VÉHICULE / CHAUFFEUR / CONTRÔLEUR : autocomplétion, comme receptionoac-saisie.jsp ──
    // (pas de Liste : VEHICULE n'a pas de colonne ACTIF et LOG_PERSONNEL n'a pas de VAL
    //  -> ORA-00904 et page blanche)
    pi.getFormu().getChamp("idvehicule").setPageAppelComplete("ferme.configuration.Vehicule","id","VEHICULE","id","id");
    pi.getFormu().getChamp("idchauffeur").setPageAppelComplete("paie.log.LogPersonnel","id","LOG_PERSONNEL","id","id");
    pi.getFormu().getChamp("idcontroleur").setPageAppelComplete("paie.log.LogPersonnel","id","LOG_PERSONNEL","id","id");

    // Verrouillage si on arrive depuis la fiche aéroport ou le lot
    String idlot = request.getParameter("idlot");
    if (idlot != null && !idlot.isEmpty()) {
        pi.getFormu().getChamp("idlot").setDefaut(idlot);
        pi.getFormu().getChamp("idlot").setAutre("readonly");
    }

    // ── DÉTAIL : uniquement les pertes du trajet (MORT / PERDU) ──
    Liste[] listef = new Liste[1];
    listef[0] = new Liste("idqualitepoussin", new QualitePoussin(), "val", "id");
    listef[0].setApresW(" and id in ('" + ConstanteFerme.qualiteMort + "','" + ConstanteFerme.qualitePerdu + "')");
    pi.getFormufle().changerEnChamp(listef);
    pi.getFormufle().getChamp("idqualitepoussin_0").setLibelle("Perte (mort / perdu)");
    pi.getFormufle().getChamp("qte_0").setLibelle("Quantit&eacute;");

    affichage.Champ.setVisible(pi.getFormufle().getChampFille("id"), false);
    affichage.Champ.setVisible(pi.getFormufle().getChampFille("idmere"), false);
    affichage.Champ.setVisible(pi.getFormufle().getChampFille("idsexe"), false);

    String[] colOrdre = {"idqualitepoussin", "qte"};
    pi.getFormufle().setColOrdre(colOrdre);

    pi.preparerDataFormu();
    pi.getFormu().makeHtmlInsertTabIndex();
    pi.getFormufle().makeHtmlInsertTableauIndex();
%>
<div class="content-wrapper">
    <h1>Saisie d'une r&eacute;ception usine</h1>
    <p class="text-muted">
        Choisissez le lot (sa r&eacute;ception &agrave; l'a&eacute;roport doit &ecirc;tre valid&eacute;e),
        puis saisissez uniquement les pertes du trajet
    </p>
    <form id="formId" class="container"
          action="<%= pi.getLien() %>?but=apresMultiple.jsp" method="post">
        <% out.println(pi.getFormu().getHtmlInsert()); %>
        <div id="butfillejsp">
            <% out.println(pi.getFormufle().getHtmlTableauInsert()); %>
        </div>
        <input name="acte"        type="hidden" value="insert">
        <input name="bute"        type="hidden" value="ferme/receptionusine/receptionusine-fiche.jsp">
        <input name="classe"      type="hidden" value="ferme.receptionusine.ReceptionUsine">
        <input name="classefille" type="hidden" value="ferme.receptionusine.ReceptionUsineDetail">
        <input name="nombreLigne" type="hidden" value="<%= nombreLigne %>">
        <input name="colonneMere" type="hidden" value="idmere">
    </form>
</div>
<% } catch (Exception e) {
    e.printStackTrace();
%>
<script>alert('<%= e.getMessage() %>'); history.back();</script>
<% } %>
