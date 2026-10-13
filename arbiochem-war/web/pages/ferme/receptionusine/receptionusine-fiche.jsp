<%@ page pageEncoding="UTF-8" contentType="text/html; charset=UTF-8" %>
<%@ page import="user.UserEJB" %>
<%@ page import="affichage.PageConsulte" %>
<%@ page import="ferme.receptionusine.*" %>
<%@ page import="utilitaire.ConstanteEtat" %>
<% try{
    UserEJB u = (UserEJB) session.getValue("u");
    String lien = (String) session.getValue("lien");

    ReceptionUsineLib o = new ReceptionUsineLib();
    PageConsulte pc = new PageConsulte(o, request, u);
    pc.setTitre("Fiche d'une r&eacute;ception usine");
    String id = pc.getBase().getTuppleID();

    pc.getChampByName("id").setLibelle("Id");
    pc.getChampByName("idlot").setLibelle("Id Lot");
    pc.getChampByName("idlotlib").setLibelle("Lot");
    pc.getChampByName("daty").setLibelle("Date");
    pc.getChampByName("heuredepart").setLibelle("Heure de d&eacute;part");
    pc.getChampByName("heurearrive").setLibelle("Heure d'arriv&eacute;e");
    pc.getChampByName("idvehicule").setLibelle("V&eacute;hicule");
    pc.getChampByName("idchauffeur").setLibelle("Chauffeur");
    pc.getChampByName("idcontroleur").setLibelle("Contr&ocirc;leur");
    pc.getChampByName("remarque").setLibelle("Remarque");
    pc.getChampByName("qteattendue").setLibelle("Vivants &agrave; l'a&eacute;roport");
    pc.getChampByName("nbmort").setLibelle("Morts");
    pc.getChampByName("nbperdu").setLibelle("Perdus");
    pc.getChampByName("nbvivant").setLibelle("Vivants &agrave; l'usine");
    pc.getChampByName("etatlib").setLibelle("&Eacute;tat");
    pc.getChampByName("etat").setVisible(false);
    // pas de sexe ni de cartons avant la répartition en parquets
    pc.getChampByName("nbrcartonmale").setVisible(false);
    pc.getChampByName("nbrcartonfemelle").setVisible(false);
    pc.getChampByName("qterecus").setVisible(false);     // = nbvivant
    pc.getChampByName("idlot").setLien(lien + "?but=ferme/lot/lot-fiche.jsp", "id=");

    String[] ordre = {"id","idlot","idlotlib","daty","heuredepart","heurearrive",
                      "idvehicule","idchauffeur","idcontroleur","remarque",
                      "qteattendue","nbmort","nbperdu","nbvivant","etatlib"};
    pc.setOrdre(ordre);

    String pageActuel = "ferme/receptionusine/receptionusine-fiche.jsp";
    String pageRetour = "ferme/receptionusine/receptionusine-liste.jsp";
    String classe     = "ferme.receptionusine.ReceptionUsine";

    ReceptionUsineLib base = (ReceptionUsineLib) pc.getBase();
%>
<div class="content-wrapper">
    <h1 class="box-title">
        <a href="<%= lien %>?but=<%= pageRetour %>"><i class="fa fa-angle-left"></i></a>
        <%= pc.getTitre() %>
    </h1>
    <div class="row m-0">
        <div class="col-md-3"></div>
        <div class="col-md-6">
            <div class="box-fiche">
                <div class="box">
                    <div class="box-body">
                        <% out.println(pc.getHtml()); %>
                        <br/>
                        <div class="box-footer">
                        <% if (base.getEtat() < ConstanteEtat.getEtatValider()) { %>
                            <a class="btn btn-primary pull-right"
                               href="<%= lien %>?but=apresTarif.jsp&id=<%= id %>&acte=valider&bute=<%= pageActuel %>&classe=<%= classe %>">Valider</a>
                            <a class="btn btn-danger pull-left"
                               href="<%= lien %>?but=apresTarif.jsp&id=<%= id %>&acte=delete&bute=<%= pageRetour %>&classe=<%= classe %>">Supprimer</a>
                        <% } else { %>
                            <a class="btn btn-secondary pull-right"
                               href="<%= lien %>?but=ferme/triagebatiment/triagebatimentparquet-saisie.jsp&idLot=<%= base.getIdlot() %>">R&eacute;partir en parquets</a>
                        <% } %>
                        </div>
                        <br/>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <div class="row m-0">
        <div class="col-md-12 nopadding">
            <div class="nav-tabs-custom">
                <ul class="nav nav-tabs">
                    <li class="active"><a href="#">Pertes (morts / perdus)</a></li>
                </ul>
                <div class="tab-content">
                    <jsp:include page="inc/receptionusine-details.jsp">
                        <jsp:param name="id" value="<%= id %>" />
                    </jsp:include>
                </div>
            </div>
        </div>
    </div>
</div>
<% } catch (Exception e){
    e.printStackTrace();
%>
<script>alert('<%= e.getMessage() %>'); history.back();</script>
<% } %>
