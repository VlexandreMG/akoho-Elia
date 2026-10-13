<%--
  Onglet "Détails" de la fiche BC fournisseur
  Affiche les LIGNES du bon de commande (les produits) sous forme de tableau.

  Ce fichier est INCLUS par bondecommande-arbiochem-fiche.jsp via :
      <jsp:include page="inc/bondecommande-liste-detail.jsp">
          <jsp:param name="idFactureFournisseur" value="..." />
      </jsp:include>

  Il reçoit donc l'id du BC dans le request.
--%>

<%-- ═══════════════════════════════════════════════════════════════
     BLOC 0 — IMPORTS
     ═══════════════════════════════════════════════════════════════ --%>
<%@page import="faturefournisseur.As_BonDeCommande_Fille_CPL"%>  <%-- La classe "fille complétée" --%>
<%@ page pageEncoding="UTF-8" contentType="text/html; charset=UTF-8;" %>
<%@ page import="user.*" %>              <%-- UserEJB --%>
<%@ page import="bean.*" %>              <%-- AdminGen, ClassMAPTable --%>
<%@ page import="utilitaire.*" %>        <%-- Utilitaire, AdminGen --%>
<%@ page import="affichage.*" %>         <%-- PageRecherche --%>

<%
    try {

    // ═══════════════════════════════════════════════════════════════
    // BLOC 1 — CRÉATION DE L'OBJET À LISTER
    //
    // On utilise As_BonDeCommande_Fille_CPL = la version "complétée"
    // de la fille (avec les libellés joints : produitlib, unitelib…).
    // Et on force la table source à AS_BONDECOMMANDE_CPL
    // (une vue qui joint les lignes + libellés).
    // ═══════════════════════════════════════════════════════════════
    As_BonDeCommande_Fille_CPL t = new As_BonDeCommande_Fille_CPL();
    t.setNomTable("AS_BONDECOMMANDE_CPL");

    // ═══════════════════════════════════════════════════════════════
    // BLOC 2 — CRITÈRES DE RECHERCHE (vides ici)
    //
    // listeCrt  = champs cherchables (recherche simple)
    // listeInt  = champs à intervalle (min/max)
    // Ici, tableaux VIDES → pas de filtres visibles.
    // ═══════════════════════════════════════════════════════════════
    String listeCrt[] = {};
    String listeInt[] = {};

    // ═══════════════════════════════════════════════════════════════
    // BLOC 3 — COLONNES À AFFICHER
    //
    // ⭐ Ce sont les NOMS TECHNIQUES des champs Java (= colonnes de la vue).
    //    L'ordre compte : c'est l'ordre d'affichage.
    // ═══════════════════════════════════════════════════════════════
    String libEntete[] = {
        "id",              // id de la ligne
        "produitlib",      // libellé du produit
        "quantite",        // quantité
        "unitelib",        // libellé de l'unité (kg, sac, …)
        "pu",              // prix unitaire
        "montantHT",       // montant HT
        "remiseMontant",   // montant de la remise
        "montantTva",      // montant TVA
        "montantTTC",      // montant TTC
        "tauxDeChange",    // taux de change
        "montantTtcAr"     // montant TTC en Ariary
    };

    // ═══════════════════════════════════════════════════════════════
    // BLOC 4 — CRÉATION DE LA PAGE DE RECHERCHE
    //
    // PageRecherche = classe APJ qui affiche un TABLEAU de résultats.
    // Signature :
    //   PageRecherche(objet, request, listeCrt, listeInt,
    //                 nbChampsCritere, libEntete, nbColonnes)
    // ═══════════════════════════════════════════════════════════════
    PageRecherche pr = new PageRecherche(
        t,                    // l'objet (As_BonDeCommande_Fille_CPL)
        request,              // pour lire les filtres
        listeCrt,             // critères simples (vide)
        listeInt,             // critères à intervalle (vide)
        3,                    // nombre de champs critère affichés
        libEntete,            // colonnes à afficher
        libEntete.length      // nombre de colonnes
    );

    pr.setUtilisateur((user.UserEJB) session.getValue("u"));
    pr.setLien((String) session.getValue("lien"));

    // ═══════════════════════════════════════════════════════════════
    // BLOC 5 — ⭐ LE FILTRE PRINCIPAL : idbc = id du BC parent
    //
    // C'est CE filtre qui fait qu'on n'affiche QUE les lignes
    // du BC qu'on est en train de consulter.
    //
    // "id" vient du request (passé par la fiche).
    // ═══════════════════════════════════════════════════════════════
    if (request.getParameter("id") != null) {
        pr.setAWhere(" and idbc='" + request.getParameter("id") + "'");
    }
    // → la requête devient :
    //   SELECT * FROM AS_BONDECOMMANDE_CPL WHERE idbc = 'BC001'

    // ═══════════════════════════════════════════════════════════════
    // BLOC 6 — GÉNÉRATION DE LA PAGE
    //
    // ⚠ creerObjetPage() est OBLIGATOIRE : c'est elle qui exécute
    //   la requête SQL et construit le tableau HTML.
    //
    // colSomme = null → pas de colonne de somme automatique dans
    //   le pied du tableau (on fait le récap à la main plus bas).
    // ═══════════════════════════════════════════════════════════════
    String[] colSomme = null;
    pr.creerObjetPage(libEntete, colSomme);

%>

<%-- ═══════════════════════════════════════════════════════════════
     PARTIE HTML — Affichage
     ═══════════════════════════════════════════════════════════════ --%>
<div class="box-body">
<%
    // ═══════════════════════════════════════════════════════════════
    // BLOC 7 — LIBELLÉS "JOLIS" DES COLONNES
    //
    // libEntete      = noms techniques (pour la requête)
    // libEnteteAffiche = libellés affichés (pour l'utilisateur)
    //
    // ⚠ Les deux tableaux DOIVENT avoir le même ordre et la même taille.
    // ═══════════════════════════════════════════════════════════════
    String libEnteteAffiche[] = {
        "id",
        "produit",
        "Quantit&eacute;",
        "unit&eacute;",
        "Prix unitaire HT",
        "Montant HT",
        "Montant remise",
        "Montant TVA",
        "Montant TTC",
        "Taux de change",
        "Montant TTC Ar"
    };
    pr.getTableau().setLibelleAffiche(libEnteteAffiche);

    // ═══════════════════════════════════════════════════════════════
    // BLOC 8 — AFFICHAGE DU TABLEAU (s'il y a des données)
    // ═══════════════════════════════════════════════════════════════
    if (pr.getTableau().getHtml() != null) {
        // ⭐ Affiche le tableau HTML généré par APJ
        out.println(pr.getTableau().getHtml());
%>

    <%-- ═══════════════════════════════════════════════════════════════
         BLOC 9 — RÉCAP DES MONTANTS (petit tableau en bas à droite)

         ⭐ AdminGen.calculSommeDouble(pr.getListe(), "champ")
            = calcule la SOMME d'un champ sur tous les enregistrements.

         ⭐ pr.getListe() = le tableau d'objets résultat de la requête.
         ═══════════════════════════════════════════════════════════════ --%>
    <div class="w-100" style="display: flex; flex-direction: row-reverse;">
        <table style="width: 20%" class="table">

            <%-- Somme Montant HT --%>
            <tr>
                <td><b>Montant HT:</b></td>
                <td><b>
                    <%= Utilitaire.formaterAr(AdminGen.calculSommeDouble(pr.getListe(), "montantHT")) %>
                    <%= ((As_BonDeCommande_Fille_CPL) pr.getListe()[0]).getIdDevise() %>
                </b></td>
            </tr>

            <%-- Somme Montant TVA --%>
            <tr>
                <td><b>Montant TVA:</b></td>
                <td><b>
                    <%= Utilitaire.formaterAr(AdminGen.calculSommeDouble(pr.getListe(), "montantTVA")) %>
                    <%= ((As_BonDeCommande_Fille_CPL) pr.getListe()[0]).getIdDevise() %>
                </b></td>
            </tr>

            <%-- Somme Montant Remise --%>
            <tr>
                <td><b>Montant Remise:</b></td>
                <td><b>
                    <%= Utilitaire.formaterAr(AdminGen.calculSommeDouble(pr.getListe(), "remiseMontant")) %>
                    <%= ((As_BonDeCommande_Fille_CPL) pr.getListe()[0]).getIdDevise() %>
                </b></td>
            </tr>

            <%-- Somme Montant TTC --%>
            <tr>
                <td><b>Montant TTC:</b></td>
                <td><b>
                    <%= Utilitaire.formaterAr(AdminGen.calculSommeDouble(pr.getListe(), "montantTTC")) %>
                    <%= ((As_BonDeCommande_Fille_CPL) pr.getListe()[0]).getIdDevise() %>
                </b></td>
            </tr>

        </table>
    </div>
<%
    }

    // ═══════════════════════════════════════════════════════════════
    // BLOC 10 — CAS "AUCUNE DONNÉE"
    // ═══════════════════════════════════════════════════════════════
    if (pr.getTableau().getHtml() == null) {
%>
        <div style="text-align: center;">
            <h4>Aucune donnée trouvée</h4>
        </div>
<%
    }
%>
</div>

<%-- ═══════════════════════════════════════════════════════════════
     BLOC 11 — CATCH FINAL (pattern APJ)
     ═══════════════════════════════════════════════════════════════ --%>
<%
} catch (Exception e) {
    e.printStackTrace();
}
%>