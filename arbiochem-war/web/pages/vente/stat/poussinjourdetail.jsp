<%--
  Poussins obtenus par jour (prévisionnel).
  Copie de vente/stat/cajourdetail.jsp : même grille mois x jours-semaine,
  mais chaque case affiche une QUANTITE de poussins (entier) au lieu d'un
  montant CA. Données : vente.stat.PoussinJourDetail.getPrevisionsParMois().
--%>
<%@ page import="vente.stat.PoussinJourDetail" %>
<%@ page import="java.util.*" %>

<%
    PoussinJourDetail cad = new PoussinJourDetail();
    Map<String, PoussinJourDetail[]> data = cad.getPrevisionsParMois();

    List<String> moisList = new ArrayList<>(data.keySet());

    Map<String, Map<String, PoussinJourDetail>> rows = new LinkedHashMap<>();

    int maxJour = 0;
    for (String mois : moisList) {
        PoussinJourDetail[] details = data.get(mois);
        maxJour = details.length;
        int i=0;
        for (PoussinJourDetail d : details) {
            String ref = i+mois ;
            rows.putIfAbsent(ref, new LinkedHashMap<>());
            rows.get(ref).put(mois, d);
            i++;
        }
    }
%>

<style>
    .table-container {
        max-width: 100%;
        max-height: 80vh;
        overflow-y: auto;
        overflow-x: auto;
        border: 1px solid #ccc;
    }

    table {
        border-collapse: collapse;
        width: 100%;
        table-layout: fixed;
    }

    th, td {
        border: 1px solid #999;
        padding: 6px;
        text-align: right;
        font-size: 12px;
    }

    th {
        background-color: #f2f2f2;
        text-align: center;
        position: sticky;
        top: 0;
        z-index: 2;
    }

    .jour-cell {
        text-align: center;
        position: sticky;
        left: 0;
        background: #fff;
        z-index: 1;
        width: 120px;
    }

    .jour{

        text-align: left;
        position: sticky;
        left: 0;
        background: #fff;
        z-index: 3;
        min-width: 120px;
        max-width: 120px;
        white-space: nowrap;
    }

    .dimanche {
        background-color: #fdd;
    }

    .ca {
        color: #000;
    }
    .montant{
        text-align: right;
    }

    .total{
        font-weight: bold;
    }

</style>

<div class="content-wrapper">
    <section class="content-header">
        <h1>Poussins obtenus par jour (prévisionnel)</h1>
    </section>
    <div class="table-container">
        <table id="tableId">
            <thead>
            <tr style="position: sticky;top:0;z-index: 5;">
                <th class="jour-cell jour">JOUR</th>
                <% for (String mois : moisList) { %>
                <th class="jour-cell" style="width: 50px;">DATE</th>
                <th class="jour-cell"><%= mois.toUpperCase() %></th>
                <% } %>
            </tr>
            </thead>
            <tbody>
            <% for (int jour =0; jour < maxJour; jour++) { %>
            <tr>

                <%
                    boolean isDimanche2 = false;
                    boolean isTotal2 = false;
                    boolean isMoyen2 = false;
                    String jourlib = "-";
                    for (String mois : moisList) {
                        String ref = jour+mois ;
                        PoussinJourDetail d = rows.containsKey(ref) ? rows.get(ref).get(mois) : null;
                        if (d != null && d.getJourlib() != null && !d.getJourlib().isEmpty()) {
                            jourlib = d.getJourlib();
                            isDimanche2 = d.getJourlib().toLowerCase().contains("dimanche");
                            isTotal2 = d.getJourlib().toLowerCase().contains("total");
                            isMoyen2 = d.getJourlib().toLowerCase().contains("moyen");
                            break;
                        }
                    }
                %>
                <td class="jour-cell jour <%= isMoyen2 ? "total" : "" %> <%= isTotal2 ? "total" : "" %> <%= isDimanche2 ? "dimanche" : "" %>">
                    <%= jourlib.toUpperCase() %>
                </td>

                <% for (String mois : moisList) {
                    String ref = jour+mois ;
                    PoussinJourDetail d = rows.containsKey(ref) ? rows.get(ref).get(mois) : null;
                    boolean isDimanche = d != null && d.getJourlib() != null && d.getJourlib().toLowerCase().contains("dimanche");
                    boolean isTotal = d != null && d.getJourlib() != null && d.getJourlib().toLowerCase().contains("total");
                    boolean isMoyen = d != null && d.getJourlib() != null && d.getJourlib().toLowerCase().contains("moyen");
                    int qte = (d != null) ? d.getQte() : 0;
                    int jj = (d == null || d.getJour()==0) ? -1 : d.getJour();
                    if(isTotal || isMoyen){
                %>
                <td class="jour-cell montant total" colspan="2"><%= qte > 0 ? String.format("%,d", qte) : "-" %></td>
                <%}else{%>
                <td class="jour-cell <%= isDimanche ? "dimanche" : "" %>"><%= jj < 0 ? "-" : jj+"" %></td>
                <td class="jour-cell <%= isDimanche ? "dimanche" : "" %> montant">
                    <%= qte > 0 ? String.format("%,d", qte) : "-" %>
                </td>
                <% } } %>
            </tr>
            <% } %>
            </tbody>
        </table>
    </div>
    <button onclick="exportTableToExcel('tableId', 'poussins_journalier')">Exporter Excel</button>
</div>
<script>
    function exportTableToExcel(tableID, filename = ''){
        var dataType = 'application/vnd.ms-excel';
        var tableSelect = document.getElementById(tableID);
        var tableHTML = tableSelect.outerHTML.replace(/ /g, '%20');

        filename = filename ? filename + '.xls' : 'export_excel.xls';

        var downloadLink = document.createElement("a");
        document.body.appendChild(downloadLink);

        if(navigator.msSaveOrOpenBlob){
            var blob = new Blob(['\ufeff', tableHTML], { type: dataType });
            navigator.msSaveOrOpenBlob(blob, filename);
        }else{
            downloadLink.href = 'data:' + dataType + ', ' + tableHTML;
            downloadLink.download = filename;
            downloadLink.click();
        }
    }
</script>
