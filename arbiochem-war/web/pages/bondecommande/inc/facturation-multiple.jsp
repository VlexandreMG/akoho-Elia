<%--
  Onglet "Facturation multiple" de la fiche BC fournisseur.

  RÔLE :
  Afficher la liste des BONS DE LIVRAISON rattachés au BC courant,
  qui sont VALIDÉS et PAS ENCORE FACTURÉS.
  Chaque ligne a une CASE À COCHER → on peut en sélectionner plusieurs
  et les facturer ENSEMBLE en un clic.

  C'est ce qu'on appelle la "facturation multiple" :
  plusieurs livraisons → une seule facture fournisseur.

  Ce fichier est INCLUS par bondecommande-arbiochem-fiche.jsp via :
      <jsp:include page="inc/facturation-multiple.jsp" />
--%>

<%-- ═══════════════════════════════════════════════════════════════
     BLOC 0 — IMPORTS
     ═══════════════════════════════════════════════════════════════ --%>
<%@page import="faturefournisseur.As_BonDeLivraison_Lib"%>  <%-- La classe "libellés" du BL --%>
<%@ page pageEncoding="UTF-8" contentType="text/html; charset=UTF-8;" %>
<%@ page import="user.*" %>              <%-- UserEJB --%>
<%@ page import="bean.*" %>              <%-- ConstanteEtat, ClassMAPTable --%>
<%@ page import="utilitaire.*" %>        <%-- Utilitaire --%>
<%@ page import="affichage.*" %>         <%-- PageRecherche --%>

<% try {

    // ═══════════════════════════════════════════════════════════════
    // BLOC 1 — CRÉATION DE L'OBJET À LISTER
    //
    // As_BonDeLivraison_Lib = version "libellés" du Bon de Livraison
    // (avec magasinlib, etc.).
    //
    // ⚠ Contrairement aux autres incs, on ne fait PAS de
    //    t.setNomTable(...) : la classe utilise sa table par défaut.
    // ═══════════════════════════════════════════════════════════════
    As_BonDeLivraison_Lib t = new As_BonDeLivraison_Lib();

    // ═══════════════════════════════════════════════════════════════
    // BLOC 2 — CRITÈRES DE RECHERCHE (vides)
    // ═══════════════════════════════════════════════════════════════
    String[] listeCrt = {};
    String[] listeInt = {};

    // ═══════════════════════════════════════════════════════════════
    // BLOC 3 — COLONNES À AFFICHER
    // 4 colonnes seulement (l'inc est compact).
    // ═══════════════════════════════════════════════════════════════
    String[] libEntete = {"id", "remarque", "daty", "magasinlib"};

    // ═══════════════════════════════════════════════════════════════
    // BLOC 4 — CRÉATION DE LA PAGE DE RECHERCHE
    // ═══════════════════════════════════════════════════════════════
    PageRecherche pr = new PageRecherche(
        t, request, listeCrt, listeInt,
        3,                    // nb champs critère
        libEntete, libEntete.length
    );

    // ⚠ getAttribute au lieu de getValue ici (les deux marchent)
    pr.setUtilisateur((user.UserEJB) session.getAttribute("u"));
    pr.setLien((String) session.getAttribute("lien"));

    // ═══════════════════════════════════════════════════════════════
    // BLOC 5 — ⭐⭐ LE FILTRE LE PLUS IMPORTANT DE CET INC
    //
    // On ne veut QUE les BL qui sont :
    //   1. rattachés au BC courant        → idbc = ?id
    //   2. PAS ENCORE FACTURÉS            → idFactureFournisseur IS NULL
    //   3. VALIDÉS                        → etat = 11
    //
    // C'est CE triple filtre qui fait qu'on ne propose QUE les BL
    // facturables. Sans lui, on pourrait facturer 2 fois le même BL.
    // ═══════════════════════════════════════════════════════════════
    if (request.getParameter("id") != null) {
        pr.setAWhere(
            " and idFactureFournisseur is null"           // pas encore facturé
          + " and etat = " + ConstanteEtat.getEtatValider() // validé (11)
          + " and idbc='" + request.getParameter("id") + "'" // du BC courant
        );
    }

    // ═══════════════════════════════════════════════════════════════
    // BLOC 6 — GÉNÉRATION DE LA PAGE
    // ═══════════════════════════════════════════════════════════════
    pr.creerObjetPage(libEntete, null);

    // ═══════════════════════════════════════════════════════════════
    // BLOC 7 — LIBELLÉS "JOLIS" + LIEN CLIQUABLE
    // ═══════════════════════════════════════════════════════════════
    String[] libEnteteAffiche = {"Id", "Remarque", "Date", "Magasin"};

    String[] lienTableau = {
        pr.getLien() + "?but=bondelivraison/bondelivraison-fiche.jsp"
    };
    String[] colonneLien = {"id"};

    pr.getTableau().setLien(lienTableau);
    pr.getTableau().setColonneLien(colonneLien);
    pr.getTableau().setLibelleAffiche(libEnteteAffiche);
%>

<%-- ═══════════════════════════════════════════════════════════════
     PARTIE HTML — le formulaire de facturation multiple
     ═══════════════════════════════════════════════════════════════ --%>
<div class="box-body">

    <%-- ⭐⭐ LE FORMULAIRE DE SÉLECTION MULTIPLE
         Action : ouvrir la saisie de facture fournisseur
         en passant l'idbc (le BC parent).
    --%>
    <form action="<%= pr.getLien() + "?but=facturefournisseur/facturefournisseur-saisie.jsp&idbc=" + request.getParameter("id") %>"
          method="post"
          onsubmit="supprimerNullIds(this)">   <%-- ⭐ appel JS avant envoi --%>

        <%-- Champ caché "acte" : sera rempli par le bouton cliqué --%>
        <input type="hidden" name="acte">

        <%
        // ═══════════════════════════════════════════════════════════════
        // BLOC 8 — ⭐ AFFICHAGE AVEC CASES À COCHER
        //
        // getHtmlWithCheckbox() au lieu de getHtml() :
        //   → ajoute une case à cocher sur chaque ligne
        //   → chaque checkbox a name="id" et value=<id du BL>
        //
        // Du coup, à la soumission, on reçoit request.getParameterValues("id")
        // = la liste des BL cochés.
        // ═══════════════════════════════════════════════════════════════
        if (pr.getTableau().getHtmlWithCheckbox() != null) {
            out.println(pr.getTableau().getHtmlWithCheckbox());
        } else {
        %>
            <div style="text-align: center;">
                <h4>Aucune donnée trouvée</h4>
            </div>
        <%
        }
        %>
    </form>

    <%
    // ═══════════════════════════════════════════════════════════════
    // BLOC 9 — PAGINATION (boutons page précédente/suivante)
    // ═══════════════════════════════════════════════════════════════
    out.println(pr.getBasPage());
    %>
</div>

<%-- ═══════════════════════════════════════════════════════════════
     SCRIPT JS — nettoyage avant envoi du formulaire

     PROBLÈME À RÉSOUDRE :
     APJ génère des <input name="id"> pour TOUTES les lignes, même
     celles sans id (lignes vides du tableau). Ces inputs ont alors
     value="" ou value="null".

     Si on les envoie, le serveur reçoit des id parasites.

     SOLUTION :
     Avant la soumission, on supprime du DOM tous les <input name="id">
     dont la valeur est vide ou "null".
     ═══════════════════════════════════════════════════════════════ --%>
<script>
    function supprimerNullIds(form) {
        // Parcourt tous les <input name="id"> du formulaire
        form.querySelectorAll('input[name="id"]').forEach(function(input) {
            // Si la valeur est "null" ou vide → supprime l'input du DOM
            if (input.value === 'null' || input.value === '') {
                input.parentNode.removeChild(input);
            }
        });
        return true;   // autorise la soumission du formulaire
    }
</script>

<%-- ═══════════════════════════════════════════════════════════════
     CATCH FINAL (pattern APJ avec alerte + retour)
     ═══════════════════════════════════════════════════════════════ --%>
<% } catch (Exception e) {
    e.printStackTrace();
%>
    <script language="JavaScript">
        alert('<%=e.getMessage()%>');
        history.back();
    </script>
<% } %>