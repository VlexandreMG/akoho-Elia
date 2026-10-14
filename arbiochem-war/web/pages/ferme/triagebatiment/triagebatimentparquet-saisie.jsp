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
<%@ page import="ferme.configuration.QualitePoussin" %>

<% try{ 
    UserEJB u = (user.UserEJB) session.getValue("u");
    String classeMere = "ferme.triageBatiment.TriageBatimentParquet";
    String classeFille = "ferme.triageBatiment.TriageBatimentParquetDetail";
    String nomTableFille = "TRIAGEBATIMENTPARQUETDETAIL";
    String colonneMere = "idmere";
    String apres = "ferme/triagebatiment/triagebatimentparquet-fiche.jsp";

    String idLot = request.getParameter("idLot");

    TriageBatimentParquet mere = new TriageBatimentParquet();
    mere.setNomTable("TRIAGEBATIMENTPARQUET");
    TriageBatimentParquetDetail fille = new TriageBatimentParquetDetail();
    fille.setNomTable("TRIAGEBATIMENTPARQUETDETAIL");
    int taille = 10;
    PageInsertMultiple pi = new PageInsertMultiple(mere, fille, request, taille, u);
    pi.setLien((String) session.getValue("lien"));  
    pi.setTitre("Saisie triage par compartiment");


    pi.getFormu().getChamp("daty").setLibelle("Date");
    pi.getFormu().getChamp("idlot").setLibelle("lot");
    pi.getFormu().getChamp("etat").setVisible(false);
    // Le sexe n'apparaît qu'ici : avant, on ne connaît qu'un TOTAL de vivants.
    //   dispo = vivants de la réception usine validée - déjà réparti (recalculé en Java)
    pi.getFormu().getChamp("dispo").setLibelle("Vivants disponibles");
    pi.getFormu().getChamp("dispo").setAutre("readonly");
    pi.getFormu().getChamp("dispomale").setVisible(false);
    pi.getFormu().getChamp("dispofemelle").setVisible(false);
    pi.getFormu().getChamp("idlot").setPageAppelComplete("ferme.lot.Lot","id","LOT","id","id");
    if(idLot != null && !idLot.isEmpty()){
        pi.getFormu().getChamp("idlot").setDefaut(idLot);
        pi.getFormu().getChamp("idlot").setAutre("readonly");
        pi.getFormu().getChamp("dispo").setDefaut(Double.toString(mere.getDispoLot(idLot, null)));
    }


    // Le batiment est ignore : un compartiment = un parquet (tous les parquets),
    // et sa capacite max est saisie ici, sur la ligne (capmax).
    Liste[] liste = new Liste[3];
    TypeObjet sexe = new TypeObjet();
    sexe.setNomTable("SEXE");
    liste[0] = new Liste("idsexe", sexe, "val", "id");
    liste[1] = new Liste("idparquet", new TypeObjet("PARQUET"), "val", "id");

    // ETAT DE SANTE en SELECT : 10 = sain, 1..9 = malade (plus de mort au triage)
    TypeObjet etatSante = new TypeObjet("ETATSANTE");
    liste[2] = new Liste("etatsante", etatSante, "val", "id");
    liste[2].setApresW(" and id >= 1");
    liste[2].setDefaultSelected("10");   // defaut = Sain

    pi.getFormufle().changerEnChamp(liste);
    Champ.setVisible(pi.getFormufle().getChampMulitple("idbatiment").getListeChamp(),false);
    pi.getFormufle().getChamp("idparquet_0").setLibelle("Parquet");
    pi.getFormufle().getChamp("capmax_0").setLibelle("Capacit&eacute; max");
    pi.getFormufle().getChamp("idsexe_0").setLibelle("Sexe");
    pi.getFormufle().getChamp("qte_0").setLibelle("Quantit&eacute;");
    // qualité : toujours CONFORME (vivant), posée en Java
    Champ.setVisible(pi.getFormufle().getChampMulitple("idqualite").getListeChamp(),false);

    // ⭐ Les 2 champs demandes par le prof
    pi.getFormufle().getChamp("etatsante_0").setLibelle("&Eacute;tat de sant&eacute;");
    pi.getFormufle().getChamp("remarque_0").setLibelle("Remarque");
    pi.getFormufle().getChamp("remarque_0").setTaille(20);
    pi.getFormufle().getChamp("miniallea_0").setLibelle("miniallea");
    // pi.getFormufle().getChamp("miniallea_0").setTaille(40);

    Champ.setVisible(pi.getFormufle().getChampMulitple("idmere").getListeChamp(),false);
//    Champ.setPageAppelComplete(pi.getFormufle().getChampFille("idbatiment"),"ferme.configuration.Batiment","id","BATIMENT","id","id");
//    Champ.setPageAppelComplete(pi.getFormufle().getChampFille("idparquet"),"ferme.configuration.Parquet","id","PARQUET","id","id");
//    Champ.setPageAppelComplete(pi.getFormufle().getChampFille("idsexe"),"bean.TypeObjet","id","SEXE","id","val");
//    Champ.setPageAppelComplete(pi.getFormufle().getChampFille("idqualite"),"ferme.configuration.QualitePoussin","id","QUALITEPOUSSIN","id","id");

    String[] colOrdre = {"idparquet","capmax","idsexe","qte","etatsante","remarque","miniallea"};
    pi.getFormufle().setColOrdre(colOrdre);

    String acte = request.getParameter("acte");
    if(acte != null && acte.equalsIgnoreCase("update")){
        pi.setTitre("Modification triage par compartiment");
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
<script language="JavaScript"> alert('<%=e.getMessage()%>');
    history.back();
</script>
<% }%>

