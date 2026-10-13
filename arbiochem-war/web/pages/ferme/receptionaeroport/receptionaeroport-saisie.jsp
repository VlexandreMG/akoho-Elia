<%@page import="ferme.receptionaeroport.*"%>
<%@page import="ferme.utils.ConstanteFerme"%>
<%@page import="user.UserEJB"%>
<%@page import="affichage.PageInsertMultiple"%>
<%@page import="affichage.Liste"%>
<%@ page import="ferme.configuration.QualitePoussin" %>
<%
    try{
    UserEJB u = null;
    u = (UserEJB) session.getValue("u");
    ReceptionPoussinAeroport mere = new ReceptionPoussinAeroport();
    ReceptionPoussinAeroportDetail fille = new ReceptionPoussinAeroportDetail();
    String idLot = request.getParameter("idLot");
    int nombreLigne = 10;
    PageInsertMultiple pi = new PageInsertMultiple(mere, fille, request, nombreLigne, u);
    pi.setLien((String) session.getValue("lien"));

    // ── EN-TÊTE : le lot + le bon de commande des poussins ──
    pi.getFormu().getChamp("idLot").setLibelle("Lot");
    pi.getFormu().getChamp("idLot").setPageAppelComplete("ferme.lot.Lot","id","LOT");
    pi.getFormu().getChamp("idLot").setPageAppelInsert("ferme/lot/lot-saisie.jsp","id;nomlot");
    pi.getFormu().getChamp("idbc").setLibelle("Bon de commande");
    pi.getFormu().getChamp("idbc").setPageAppelComplete("faturefournisseur.As_BonDeCommande","id","AS_BONDECOMMANDE");
    pi.getFormu().getChamp("daty").setLibelle("Date");
    pi.getFormu().getChamp("heureDepart").setLibelle("Heure de d&eacute;part");
    pi.getFormu().getChamp("heureDepart").setType("time");
    pi.getFormu().getChamp("heureArrive").setLibelle("Heure d'arriv&eacute;e");
    pi.getFormu().getChamp("heureArrive").setType("time");
    pi.getFormu().getChamp("remarque").setLibelle("Remarque");

    // Calculés ou inutilisés à cette étape :
    //   qteRecus = vivants = commandé - morts - perdus (calculé en Java)
    //   pas de sexe ni de cartons avant la répartition en parquets
    pi.getFormu().getChamp("etat").setVisible(false);
    pi.getFormu().getChamp("qteRecus").setVisible(false);
   // pi.getFormu().getChamp("nbrCartonMale").setVisible(false);
   // pi.getFormu().getChamp("nbrCartonFemelle").setVisible(false);

    // ── DÉTAIL : uniquement les pertes (MORT / PERDU) ──
    affichage.Liste[] listef = new Liste[1];
    QualitePoussin qp = new QualitePoussin();
    listef[0] = new Liste("idQualitePoussin", qp, "val", "id");
    listef[0].setApresW(" and id in ('" + ConstanteFerme.qualiteMort + "','" + ConstanteFerme.qualitePerdu + "')");
    pi.getFormufle().changerEnChamp(listef);
    pi.getFormufle().getChamp("idQualitePoussin_0").setLibelle("Perte (mort / perdu)");
    pi.getFormufle().getChamp("qte_0").setLibelle("Quantit&eacute;");

    affichage.Champ.setVisible(pi.getFormufle().getChampFille("id"), false);
    affichage.Champ.setVisible(pi.getFormufle().getChampFille("idMere"), false);
    affichage.Champ.setVisible(pi.getFormufle().getChampFille("idSexe"), false);

    String[] colOrdre = {"idQualitePoussin", "qte"};
    pi.getFormufle().setColOrdre(colOrdre);

    String classeMere = "ferme.receptionaeroport.ReceptionPoussinAeroport";
    String classeFille = "ferme.receptionaeroport.ReceptionPoussinAeroportDetail";
    String butApresPost = "ferme/receptionaeroport/receptionaeroport-fiche.jsp";
    String colonneMere = "idMere";

    if (idLot != null && !idLot.isEmpty()){
        pi.getFormu().getChamp("idLot").setDefaut(idLot);
        pi.getFormu().getChamp("idLot").setAutre("readonly");
    }
    pi.preparerDataFormu();
    pi.getFormu().makeHtmlInsertTabIndex();
    pi.getFormufle().makeHtmlInsertTableauIndex();

%>
<div class="content-wrapper">
    <%
        if (request.getParameter("acte")!=null && request.getParameter("acte")!=""){
            out.println("<h1>Modification du reception de poussin &agrave; l'aeroport</h1>");
        }else{
            out.println("<h1>Saisie d'un reception de poussin &agrave; l'aeroport</h1>");
        }
    %>
    <p class="text-muted">
        Choisissez le bon de commande des poussins, puis saisissez uniquement les pertes.
    </p>
    <form id="formId" class='container' action="<%=pi.getLien()%>?but=apresMultiple.jsp" method="post" >
        <%
            out.println(pi.getFormu().getHtmlInsert());
        %>
        <div id="butfillejsp">
            <%
                out.println(pi.getFormufle().getHtmlTableauInsert());
            %>
        </div>
        <input name="acte" type="hidden" id="nature" value="insert">
        <input name="bute" type="hidden" id="bute" value="<%= butApresPost %>">
        <input name="classe" type="hidden" id="classe" value="<%= classeMere %>">
        <input name="classefille" type="hidden" id="classefille" value="<%= classeFille %>">
        <input name="nombreLigne" type="hidden" id="nombreLigne" value="<%= nombreLigne %>">
        <input name="colonneMere" type="hidden" id="colonneMere" value="<%= colonneMere %>">
    </form>
</div>
<%
	} catch (Exception e) {
		e.printStackTrace();
%>
    <script language="JavaScript">
        alert('<%=e.getMessage()%>');
        history.back();
    </script>
<% }%>
