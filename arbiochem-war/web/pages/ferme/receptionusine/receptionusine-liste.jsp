<%@page import="utilitaire.Utilitaire"%>
<%@page import="ferme.receptionusine.ReceptionUsineLib"%>
<%@page import="affichage.PageRecherche"%>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%
    try {
        ReceptionUsineLib base = new ReceptionUsineLib();
        String listeCrt[] = {"idlotlib","daty"};
        String listeInt[] = {"daty"};
        String libEntete[] = {"id","idlotlib","daty","qteattendue","nbmort","nbperdu","nbvivant","etatlib"};
        PageRecherche pr = new PageRecherche(base, request, listeCrt, listeInt, 4, libEntete, libEntete.length);
        pr.setUtilisateur((user.UserEJB) session.getValue("u"));
        pr.setLien((String) session.getValue("lien"));
        pr.getFormu().getChamp("idlotlib").setLibelle("Lot");
        pr.getFormu().getChamp("daty1").setLibelle("date min");
        pr.getFormu().getChamp("daty1").setDefaut(Utilitaire.dateDuJour());
        pr.getFormu().getChamp("daty2").setLibelle("date max");
        pr.getFormu().getChamp("daty2").setDefaut(Utilitaire.dateDuJour());
        pr.setApres("ferme/receptionusine/receptionusine-liste.jsp");
        String[] colSomme = {"qteattendue","nbmort","nbperdu","nbvivant"};
        String[] labelRecap = {"","Nombres","Vivants a&eacute;roport","Morts","Perdus","Vivants usine"};
        pr.creerObjetPage(libEntete, colSomme);
        pr.getTableau().setLienFille("ferme/receptionusine/inc/receptionusine-details.jsp&id=");
        pr.getTableauRecap().setLibeEntete(labelRecap);
        pr.getFormu().setAnotherButton("" +
            "<a class=\"btn btn-primary pull-right btn-small\" href=\"module.jsp?but=ferme/receptionusine/receptionusine-saisie.jsp\">\n" +
            "                    <i class=\"material-symbols-rounded\">add</i> Saisir une r&eacute;ception usine</a>"
        );
%>
<div class="content-wrapper">
    <section class="content-header">
        <h1>Liste des r&eacute;ceptions usine</h1>
    </section>
    <section class="content">
        <form action='<%=pr.getLien() + "?but=ferme/receptionusine/receptionusine-liste.jsp" %>' method="post" name="liste" id="liste">
            <%
                out.println(pr.getFormu().getHtmlEnsemble());
            %>
        </form>
        <%
            String lienTableau[] = {pr.getLien() + "?but=ferme/receptionusine/receptionusine-fiche.jsp"};
            String colonneLien[] = {"id"};
            String attLien[] = {"id"};
            pr.getTableau().setLien(lienTableau);
            pr.getTableau().setColonneLien(colonneLien);
            pr.getTableau().setAttLien(attLien);
            out.println(pr.getTableauRecap().getHtml());
        %>
        <br/>
        <%
            String libelleAffiche[] = {"ID","Lot","Date","Vivants a&eacute;roport","Morts","Perdus","Vivants usine","&Eacute;tat"};
            pr.getTableau().setLibelleAffiche(libelleAffiche);
            out.println(pr.getTableau().getHtml());
            out.println(pr.getBasPage());
        %>
    </section>
</div>
<% } catch (Exception e) {
        e.printStackTrace();
    }%>
