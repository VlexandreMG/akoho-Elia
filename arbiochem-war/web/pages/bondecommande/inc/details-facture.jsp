<%--
  Onglet "Facture fournisseur" de la fiche BC fournisseur.

  RÔLE :
  Affiche la liste des FACTURES FOURNISSEUR rattachées au BC courant.
  Chaque ligne du tableau est cliquable → mène vers la fiche de la facture.

  Ce fichier est INCLUS par bondecommande-arbiochem-fiche.jsp via :
      <jsp:include page="inc/details-facture.jsp">
          <jsp:param name="idFactureFournisseur" value="..." />
      </jsp:include>
--%>

<%-- ═══════════════════════════════════════════════════════════════
     BLOC 0 — IMPORTS
     ═══════════════════════════════════════════════════════════════ --%>
<%@page import="faturefournisseur.FactureFournisseurCpl"%>  <%-- La classe "complétée" --%>
<%@ page pageEncoding="UTF-8" contentType="text/html; charset=UTF-8;" %>
<%@ page import="user.*" %>              <%-- UserEJB --%>
<%@ page import="bean.*" %>              <%-- AdminGen, ClassMAPTable --%>
<%@ page import="utilitaire.*" %>        <%-- Utilitaire --%>
<%@ page import="affichage.*" %>         <%-- PageRecherche, TableauRecherche --%>

<%
    try {

    // ═══════════════════════════════════════════════════════════════
    // BLOC 1 — CRÉATION DE L'OBJET À LISTER
    //
    // FactureFournisseurCpl = version "complétée" de la facture
    // fournisseur (avec les libellés joints : idFournisseurLib,
    // idServiceLib, etatlib…).
    //
    // ⭐ On force la table source à FACTUREFOURNISSEURCPL_TOUS
    //    → une vue qui liste TOUTES les factures fournisseur.
    // ═══════════════════════════════════════════════════════════════
    FactureFournisseurCpl t = new FactureFournisseurCpl();
    t.setNomTable("FACTUREFOURNISSEURCPL_TOUS");

    // ═══════════════════════════════════════════════════════════════
    // BLOC 2 — CRITÈRES DE RECHERCHE (vides)
    // Pas de champs de filtre affichés dans cet onglet.
    // ═══════════════════════════════════════════════════════════════
    String listeCrt[] = {};
    String listeInt[] = {};

    // ═══════════════════════════════════════════════════════════════
    // BLOC 3 — COLONNES À AFFICHER
    //
    // Noms TECHNIQUES (= getters de FactureFournisseurCpl).
    // L'ordre compte : c'est l'ordre des colonnes dans le tableau.
    // ═══════════════════════════════════════════════════════════════
    String libEntete[] = {
        "id",                       // ID de la facture
        "designation",              // désignation
        "idFournisseurLib",         // libellé du fournisseur
        "idDevise",                 // devise
        "daty",                     // date
        "montantttc",               // montant TTC
        "montantpaye",              // montant payé
        "montantreste",             // montant restant à payer
        "dateEcheancePaiement",     // date d'échéance
        "idServiceLib",             // département
        "etatlib"                   // état (libellé)
    };

    // ═══════════════════════════════════════════════════════════════
    // BLOC 4 — CRÉATION DE LA PAGE DE RECHERCHE
    //
    // Signature :
    //   PageRecherche(objet, request, listeCrt, listeInt,
    //                 nbChampsCritere, libEntete, nbColonnes)
    // ═══════════════════════════════════════════════════════════════
    PageRecherche pr = new PageRecherche(
        t,
        request,
        listeCrt,
        listeInt,
        3,                     // nombre de champs critère affichés
        libEntete,
        libEntete.length       // nombre de colonnes
    );

    pr.setUtilisateur((user.UserEJB) session.getValue("u"));
    pr.setLien((String) session.getValue("lien"));

    // ═══════════════════════════════════════════════════════════════
    // BLOC 5 — ⭐ LE FILTRE PRINCIPAL : idbc = id du BC parent
    //
    // On ne veut QUE les factures rattachées au BC courant.
    // L'id vient du request (l'URL de la fiche : ?id=BC001).
    //
    // "id" ici = celui du BC (pas de la facture).
    // ⚠ Le champ utilisé dans la clause est idbc (FK vers le BC).
    // ═══════════════════════════════════════════════════════════════
    if (request.getParameter("id") != null) {
        pr.setAWhere(" and idbc='" + request.getParameter("id") + "'");
    }
    // → la requête devient :
    //   SELECT * FROM FACTUREFOURNISSEURCPL_TOUS WHERE idbc = 'BC001'

    // ═══════════════════════════════════════════════════════════════
    // BLOC 6 — GÉNÉRATION DE LA PAGE
    //
    // creerObjetPage() exécute la requête et construit le tableau HTML.
    // colSomme = null → pas de colonne de somme automatique.
    // ═══════════════════════════════════════════════════════════════
    String[] colSomme = null;
    pr.creerObjetPage(libEntete, colSomme);
%>

<%-- ═══════════════════════════════════════════════════════════════
     PARTIE HTML
     ═══════════════════════════════════════════════════════════════ --%>
<div class="box-body">
<%
    // ═══════════════════════════════════════════════════════════════
    // BLOC 7 — LIBELLÉS "JOLIS" DES COLONNES
    //
    // Même ordre et même taille que libEntete du BLOC 3.
    // ═══════════════════════════════════════════════════════════════
    String libEnteteAffiche[] = {
        "ID",
        "D&eacute;signation",
        "Fournisseur",
        "devise",
        "Date",
        "Montant TTC",
        "Montant pay&eacute;",
        "Montant Restant",
        "date d'&Eacute;ch&eacute;ance de Paiement",
        "D&eacute;partement",
        "&Eacute;tat"
    };

    // ═══════════════════════════════════════════════════════════════
    // BLOC 8 — ⭐ RENDRE CHAQUE LIGNE CLIQUABLE
    //
    // On associe :
    //   - un LIEN (l'URL de destination)
    //   - une COLONNE lien (la valeur cliquable = l'id)
    //
    // Syntaxe :
    //   lienTableau  = "vers quel JSP"
    //   colonneLien  = "quel champ porte le lien"
    // ═══════════════════════════════════════════════════════════════
    String lienTableau[] = {
        pr.getLien() + "?but=facturefournisseur/facturefournisseur-fiche.jsp"
    };
    String colonneLien[] = {"id"};   // le champ "id" devient cliquable

    // Applique le lien au tableau
    pr.getTableau().setLien(lienTableau);
    pr.getTableau().setColonneLien(colonneLien);

    // Applique les libellés "jolis"
    pr.getTableau().setLibelleAffiche(libEnteteAffiche);

    // ═══════════════════════════════════════════════════════════════
    // BLOC 9 — AFFICHAGE (ou message si vide)
    // ═══════════════════════════════════════════════════════════════
    if (pr.getTableau().getHtml() != null) {
        // ⭐ Affiche le tableau HTML généré par APJ
        out.println(pr.getTableau().getHtml());
    } else {
%>
        <div style="text-align: center;">
            <h4>Aucune donnée trouvée</h4>
        </div>
<%
    }
%>
</div>

<%-- ═══════════════════════════════════════════════════════════════
     BLOC 10 — CATCH FINAL (pattern APJ)
     ═══════════════════════════════════════════════════════════════ --%>
<%
} catch (Exception e) {
    e.printStackTrace();
}
%>