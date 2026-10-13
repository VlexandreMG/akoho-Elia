<%@ page pageEncoding="UTF-8" contentType="text/html; charset=UTF-8" %>
<%@ page import="affichage.PageRecherche"%>
<%@ page import="ferme.triageBatiment.TriageBatimentParquetDetailLib"%>

<% try{
    TriageBatimentParquetDetailLib o = new TriageBatimentParquetDetailLib();
    o.setNomTable("TRIAGEBATPARQUETDETAIL_LIB");
    String[] listeCrt = {};
    String[] listeInt = {};
    String[] libEntete = {"idParquetLib","capmax","idSexeLib","etatsanteLib","qte","remarque"};
    PageRecherche pr = new PageRecherche(o, request, listeCrt, listeInt, 4, libEntete, libEntete.length);
    pr.setUtilisateur((user.UserEJB) session.getValue("u"));
    pr.setLien((String) session.getValue("lien"));

    String idTriage = request.getParameter("id");
    boolean parTriage = idTriage != null && request.getParameter("isLot") == null;
    if(parTriage){
        pr.setAWhere(" and idmere='"+idTriage+"'");
    }
    else if(idTriage != null){
        pr.setAWhere(" and idlot='"+idTriage+"'");
    }

    String[] colSomme = {"qte"};
    pr.creerObjetPage(libEntete, colSomme);

    String[] libEnteteAffiche = {"Parquet","Capacit&eacute; max","Sexe","&Eacute;tat de sant&eacute;","Quantit&eacute;","Remarque"};
    pr.getTableau().setLibelleAffiche(libEnteteAffiche);
%>


<div class="box-body">
    <%  if(pr.getTableau().getHtml() != null){
            out.println(pr.getTableau().getHtml());
        } else{ %>
            <center><h4>Aucune donn&eacute;e trouv&eacute;e</h4></center>
    <%  } %>
</div>


<% } catch (Exception e) {
  e.printStackTrace();
%>
<script language="JavaScript"> alert('<%=e.getMessage()%>');
    history.back();
</script>
<% }%>
