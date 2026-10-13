<%--
  LISTE des bons de commande fournisseur (version ARBIOCHEM)

  RÔLE :
  - Afficher un tableau de tous les BC (avec filtres)
  - Filtrer par : état, livraison, mode de paiement, dates
  - Chaque ligne est cliquable → mène vers la fiche du BC
  - Bouton "Saisir un bon de commande" → mène vers la saisie

  C'est la page d'entrée du module BC : on y arrive depuis le menu,
  et c'est vers elle qu'on revient après un "Retour" depuis la fiche.
--%>

<%-- ═══════════════════════════════════════════════════════════════
     BLOC 0 — IMPORTS
     ═══════════════════════════════════════════════════════════════ --%>
<%@page import="faturefournisseur.As_BonDeCommande"%>
<%@page import="affichage.PageRecherche"%>
<%@page import="bean.TypeObjet"%>              <%-- Pour les nomenclatures --%>
<%@page import="affichage.Liste"%>             <%-- Pour les listes déroulantes --%>
<%@ page import="java.util.Map" %>              <%-- Pour le clic droit --%>
<%@ page import="java.util.HashMap" %>
<%@ page import="faturefournisseur.As_BonDeCommandeCpl" %>  <%-- Version complétée --%>

<% try {

    // ═══════════════════════════════════════════════════════════════
    // BLOC 1 — LES OPTIONS DES FILTRES DÉROULANTS
    //
    // etatVal / etatAff = valeur technique / libellé affiché
    // Même chose pour la livraison.
    // ═══════════════════════════════════════════════════════════════
    String[] etatVal = {"", "1", "11", "0"};
    String[] etatAff = {"Tous", "Cr&eacute;&eacute;e(s)", "Vis&eacute;e(s)", "Annul&eacute;e(s)"};

    String[] etatValLiv = {"", "0", "1", "2", "3"};
    String[] etatAffLiv = {"Tous", "Non Trait&eacute;", "Trait&eacute; partiellement",
                            "Trait&eacute;", "Trait&eacute; avec surplus"};

    // ═══════════════════════════════════════════════════════════════
    // BLOC 2 — CRÉATION DE L'OBJET À LISTER
    //
    // As_BonDeCommandeCpl = version "complétée" (avec fournisseurlib,
    // modepaiementlib, idServiceLib, etatlib…).
    // On force la table source à "As_BonDeCommande_MERETRAITE".
    // ═══════════════════════════════════════════════════════════════
    As_BonDeCommandeCpl f = new As_BonDeCommandeCpl();
    f.setNomTable("As_BonDeCommande_MERETRAITE ");

    // ═══════════════════════════════════════════════════════════════
    // BLOC 3 — CHAMPS DE RECHERCHE
    //
    // listeCrt = champs cherchables par saisie texte
    // listeInt = champs à intervalle (min/max), ici daty
    // ═══════════════════════════════════════════════════════════════
    String listeCrt[] = {"id", "daty", "designation", "fournisseurlib",
                          "modepaiementlib", "reference", "refproforma"};
    String listeInt[] = {"daty"};

    // ═══════════════════════════════════════════════════════════════
    // BLOC 4 — COLONNES À AFFICHER
    // ═══════════════════════════════════════════════════════════════
    String libEntete[] = {"id", "daty", "reference", "designation",
                          "modepaiementlib", "fournisseurlib", "idServiceLib",
                          "refproforma", "etatlib", "traite"};

    // ═══════════════════════════════════════════════════════════════
    // BLOC 5 — CRÉATION DE LA PAGE DE RECHERCHE
    // ═══════════════════════════════════════════════════════════════
    PageRecherche pr = new PageRecherche(f, request, listeCrt, listeInt, 3,
                                          libEntete, libEntete.length);
    pr.setTitre("Liste des bons de commande fournisseur");

    // ═══════════════════════════════════════════════════════════════
    // BLOC 6 — ⭐ CONSTRUCTION DU FILTRE "awhere"
    //
    // On ajoute des conditions SQL selon les filtres actifs :
    //   - etat     → ?etat=1, 11, 0…
    //   - livraison → ?livraison=<idTraite>
    //
    // Le " and ..." est concaténé à la requête principale.
    // ═══════════════════════════════════════════════════════════════
    String awhere = "";

    // Filtre ÉTAT
    if (request.getParameter("etat") != null
        && request.getParameter("etat").compareToIgnoreCase("") != 0) {
        awhere += " and etat=" + request.getParameter("etat");
    }

    // Filtre LIVRAISON (par id du traite = BL)
    if (request.getParameter("livraison") != null
        && request.getParameter("livraison").compareToIgnoreCase("") != 0) {
        awhere += " and idtraite= '" + request.getParameter("livraison") + "'";
    }

    pr.setAWhere(awhere);

    // ═══════════════════════════════════════════════════════════════
    // BLOC 7 — CONFIGURATION GÉNÉRALE
    // ═══════════════════════════════════════════════════════════════
    pr.setUtilisateur((user.UserEJB) session.getValue("u"));
    pr.setLien((String) session.getValue("lien"));

    // Page vers laquelle rediriger après le POST du filtre
    pr.setApres("bondecommande/bondecommande-arbiochem-liste.jsp");

    // ═══════════════════════════════════════════════════════════════
    // BLOC 8 — LIBELLÉS DES CHAMPS DE RECHERCHE
    // ═══════════════════════════════════════════════════════════════
    pr.getFormu().getChamp("reference").setLibelle("R&eacute;f&eacute;rence");
    pr.getFormu().getChamp("designation").setLibelle("D&eacute;signation");
    pr.getFormu().getChamp("fournisseurlib").setLibelle("Fournisseur");
    pr.getFormu().getChamp("refproforma").setLibelle("R&eacute;f&eacute;rence proforma");

    // ═══════════════════════════════════════════════════════════════
    // BLOC 9 — LISTE DÉROULANTE MODE DE PAIEMENT
    //
    // On remplace le champ texte "modepaiementlib" par un <select>.
    // ⚠ La source est TypeObjet("MODEPAIEMENT") — la table est
    //    nommée explicitement avec setNomTable.
    // ═══════════════════════════════════════════════════════════════
    TypeObjet modePaiement = new TypeObjet();
    modePaiement.setNomTable("MODEPAIEMENT");

    Liste[] liste = new Liste[1];
    liste[0] = new Liste("modepaiementlib", modePaiement, "val", "val");
    pr.getFormu().changerEnChamp(liste);
    pr.getFormu().getChamp("modepaiementlib").setLibelle("Mode de paiement");

    // ═══════════════════════════════════════════════════════════════
    // BLOC 10 — DATES MIN/MAX (par défaut = aujourd'hui)
    // ═══════════════════════════════════════════════════════════════
    pr.getFormu().getChamp("daty1").setLibelle("Date min");
    pr.getFormu().getChamp("daty1").setDefaut(utilitaire.Utilitaire.dateDuJour());
    pr.getFormu().getChamp("daty2").setLibelle("Date max");
    pr.getFormu().getChamp("daty2").setDefaut(utilitaire.Utilitaire.dateDuJour());

    String[] colSomme = null;   // pas de colonne de somme

    // Nombre de résultats par page
    pr.setNpp(50);

    // ═══════════════════════════════════════════════════════════════
    // BLOC 11 — GÉNÉRATION DE LA PAGE
    // ⭐ creerObjetPage() exécute la requête et construit le tableau
    // ═══════════════════════════════════════════════════════════════
    pr.creerObjetPage(libEntete, colSomme);

    // ═══════════════════════════════════════════════════════════════
    // BLOC 12 — MENU CLIC DROIT
    //
    // Un Map associe un libellé ("modifier") à une URL.
    // ⚠ Ici, pointe vers bondecommande-modif.jsp (NON arbiochem)
    //    → probablement un bug / vestige.
    // ═══════════════════════════════════════════════════════════════
    Map<String, String> lienTab = new HashMap();
    lienTab.put("modifier", pr.getLien() + "?but=bondecommande/bondecommande-modif.jsp");
    pr.getTableau().setLienClicDroite(lienTab);

    // ═══════════════════════════════════════════════════════════════
    // BLOC 13 — ⭐ LIEN CLIQUABLE SUR CHAQUE LIGNE
    //
    // Cliquer sur l'id d'une ligne → ouvre la fiche du BC.
    // ═══════════════════════════════════════════════════════════════
    String lienTableau[] = {pr.getLien() + "?but=bondecommande/bondecommande-arbiochem-fiche.jsp"};
    String colonneLien[] = {"id"};
    pr.getTableau().setLien(lienTableau);
    pr.getTableau().setColonneLien(colonneLien);

    // ═══════════════════════════════════════════════════════════════
    // BLOC 14 — LIBELLÉS "JOLIS" DES COLONNES
    // ═══════════════════════════════════════════════════════════════
    String libEnteteAffiche[] = {"Id", "Date", "R&eacute;f&eacute;rence",
                                  "D&eacute;signation", "Mode de paiement",
                                  "Fournisseur", "D&eacute;partement",
                                  "R&eacute;f&eacute;rence proforma",
                                  "&Eacute;tat", "Livraison"};
    pr.getTableau().setLibelleAffiche(libEnteteAffiche);

    // ═══════════════════════════════════════════════════════════════
    // BLOC 15 — BOUTON "SAISIR UN BON DE COMMANDE"
    // ═══════════════════════════════════════════════════════════════
    pr.getFormu().setAnotherButton(
        "<a class=\"btn btn-primary pull-right btn-small\" " +
        "href=\"module.jsp?but=bondecommande/bondecommande-arbiochem-saisie.jsp\">\n" +
        "    <i class=\"material-symbols-rounded\">add</i> Saisir un bon de commande</a>"
    );

    // ═══════════════════════════════════════════════════════════════
    // BLOC 16 — ⭐ LIEN VERS LE DÉTAIL (lignes filles)
    //
    // Permet à APJ de savoir comment afficher le détail
    // de chaque BC (les lignes produits) en dessous.
    // ═══════════════════════════════════════════════════════════════
    pr.getTableau().setLienFille("bondecommande/inc/bondecommande-liste-detail.jsp&id=");
%>

<%-- ═══════════════════════════════════════════════════════════════
     SCRIPT JS — soumission automatique au changement
     ═══════════════════════════════════════════════════════════════ --%>
<script>
    function changerDesignation() {
        document.filtre.submit();   // soumet le formulaire de filtre
    }
</script>

<%-- ═══════════════════════════════════════════════════════════════
     PARTIE HTML
     ═══════════════════════════════════════════════════════════════ --%>
<div class="content-wrapper">
    <section class="content-header">
        <h1><%= pr.getTitre() %></h1>
    </section>

    <section class="content">
        <%-- ⭐ Le formulaire de FILTRE poste vers la même page --%>
        <form action="<%= pr.getLien() %>?but=<%= pr.getApres() %>"
              method="post" name="filtre">

            <%-- Affiche les champs de filtre générés par APJ --%>
            <% out.println(pr.getFormu().getHtmlEnsemble()); %>

            <%-- ═══════════════════════════════════════════════════════════════
                 FILTRES PERSONNALISÉS (non générés par APJ)
                 Deux <select> faits à la main :
                   - État du BC (Créé, Visé, Annulé…)
                   - État de livraison (Non traité, Partiel, Traité…)
                 ═══════════════════════════════════════════════════════════════ --%>
            <div class="row col-md-12" style="margin-top: 12px;">

                <%-- Filtre ÉTAT --%>
                <div class="col-md-2 nopadding" style="width: 271px;">
                    <label class="input-label" for="etat">&Eacute;tat :</label>
                    <select name="etat" class="champ form-control" id="etat"
                            onchange="changerDesignation()">
                        <%
                        for (int i = 0; i < etatAff.length; i++) {
                            // Si la valeur est déjà sélectionnée → selected
                            if (request.getParameter("etat") != null
                                && request.getParameter("etat").compareToIgnoreCase(etatVal[i]) == 0) {
                        %>
                            <option value="<%= etatVal[i] %>" selected><%= etatAff[i] %></option>
                        <%
                            } else {
                        %>
                            <option value="<%= etatVal[i] %>"><%= etatAff[i] %></option>
                        <%
                            }
                        }
                        %>
                    </select>
                </div>

                <%-- Filtre LIVRAISON --%>
                <div class="col-md-2 nopadding">
                    <label class="input-label" for="livraison">Livraison :</label>
                    <select name="livraison" class="champ form-control" id="livraison"
                            onchange="changerDesignation()">
                        <%
                        for (int i = 0; i < etatAffLiv.length; i++) {
                            if (request.getParameter("livraison") != null
                                && request.getParameter("livraison").compareToIgnoreCase(etatValLiv[i]) == 0) {
                        %>
                            <option value="<%= etatValLiv[i] %>" selected><%= etatAffLiv[i] %></option>
                        <%
                            } else {
                        %>
                            <option value="<%= etatValLiv[i] %>"><%= etatAffLiv[i] %></option>
                        <%
                            }
                        }
                        %>
                    </select>
                </div>
            </div>
        </form>

        <%-- Tableau récapitulatif (totaux) --%>
        <% out.println(pr.getTableauRecap().getHtml()); %>
        <br>

        <%-- ⭐ LE TABLEAU principal --%>
        <% out.println(pr.getTableau().getHtml()); %>

        <%-- ⭐ PAGINATION --%>
        <% out.println(pr.getBasPage()); %>
    </section>
</div>

<%-- ═══════════════════════════════════════════════════════════════
     CATCH FINAL (pattern APJ)
     ═══════════════════════════════════════════════════════════════ --%>
<%
    } catch (Exception e) {
        e.printStackTrace();
    }
%>