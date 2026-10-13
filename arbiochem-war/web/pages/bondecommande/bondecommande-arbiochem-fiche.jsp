<%--
  Fiche d'un Bon de Commande Fournisseur (version ARBIOCHEM)
  Créée par Tsinjoniaina le 10/08/2026

  RÔLE :
  - Relire un BC depuis la base à partir de son id
  - Afficher l'en-tête (les champs de la mère)
  - Afficher des BOUTONS D'ACTION (Viser, Modifier, Annuler, Réceptionner…)
  - Afficher des ONGLETS (Détails, Réception, Facture…)

  C'est la page vers laquelle on redirige APRÈS un insert/update
  (c'est le "bute" du JSP de saisie).
--%>

<%-- ═══════════════════════════════════════════════════════════════
     BLOC 0 — IMPORTS
     ═══════════════════════════════════════════════════════════════ --%>
<%@page import="faturefournisseur.*"%>              <%-- As_BonDeCommandeCpl --%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@ page import="user.*" %>                          <%-- UserEJB --%>
<%@ page import="bean.*" %>                          <%-- ClassMAPTable --%>
<%@ page import="utilitaire.*" %>                    <%-- Utilitaire --%>
<%@ page import="affichage.*" %>                     <%-- PageConsulte --%>
<%@page import="java.util.Map"%>                     <%-- Pour le Map des onglets --%>
<%@page import="java.util.HashMap"%>

<%-- ═══════════════════════════════════════════════════════════════
     BLOC 1 — RÉCUPÉRATION DE L'UTILISATEUR CONNECTÉ
     ═══════════════════════════════════════════════════════════════ --%>
<%
  UserEJB u = (user.UserEJB) session.getValue("u");
%>

<%
  try {

    // ═══════════════════════════════════════════════════════════════
    // BLOC 2 — CRÉATION DE L'OBJET À CONSULTER
    //
    // On utilise As_BonDeCommandeCpl (la version "complétée" = avec les
    // libellés joints : fournisseurlib, idDeviselib, etatlib…).
    // Et on force la table source à AS_BONDECOMMANDE_MERETRAITE.
    // ═══════════════════════════════════════════════════════════════
    As_BonDeCommandeCpl f = new As_BonDeCommandeCpl();
    f.setNomTable("AS_BONDECOMMANDE_MERETRAITE");

    // ═══════════════════════════════════════════════════════════════
    // BLOC 3 — CRÉATION DE LA PAGE DE CONSULTATION
    //
    // PageConsulte = la classe APJ qui AFFICHE un objet en lecture seule.
    // Elle prend (objet, request, user).
    // Le request contient "id" → APJ va chercher l'objet en base.
    // ═══════════════════════════════════════════════════════════════
    PageConsulte pc = new PageConsulte(f, request, u);
    String lien = (String) session.getValue("lien");

    // Titre de la page
    pc.setTitre("Fiche d'un bon de commande fournisseur");

    // ⭐ CHARGE l'objet depuis la base via son id (dans request)
    pc.getBase();

    // Récupère l'id de l'objet chargé
    String id = pc.getBase().getTuppleID();

    // ═══════════════════════════════════════════════════════════════
    // BLOC 4 — RÉGLAGE DES LIBELLÉS (ce qui s'affiche)
    //
    // Syntaxe : pc.getChampByName("nom").setLibelle("Libellé")
    // ═══════════════════════════════════════════════════════════════
    pc.getChampByName("id").setLibelle("Id");
    pc.getChampByName("daty").setLibelle("date");
    pc.getChampByName("dateLimite").setLibelle("Date limite de livraison");
    pc.getChampByName("reference").setLibelle("R&eacute;f&eacute;rence");
    pc.getChampByName("remarque").setLibelle("Remarque");
    pc.getChampByName("designation").setLibelle("d&eacute;signation");
    pc.getChampByName("fournisseurlib").setLibelle("Fournisseur");
    pc.getChampByName("modepaiementlib").setLibelle("Mode de paiement");
    pc.getChampByName("idDeviselib").setLibelle("Devise");
    pc.getChampByName("montantTVA").setLibelle("Montant TVA");
    pc.getChampByName("montantHT").setLibelle("Montant HT");
    pc.getChampByName("montantTTC").setLibelle("Montant TTC");
    pc.getChampByName("montantTTCAriary").setLibelle("Montant TTC Ariary");
    pc.getChampByName("sommeAcompte").setLibelle("Somme acompte");
    pc.getChampByName("etat").setLibelle("&Eacute;tat");
    pc.getChampByName("etatlib").setLibelle("&Eacute;tat");
    pc.getChampByName("idServiceLib").setLibelle("D&eacute;partement");
    pc.getChampByName("iddmdachat").setLibelle("Demande d'achat");
    pc.getChampByName("refproforma").setLibelle("R&eacute;f&eacute;rence proforma");

    // ⭐ Le champ "iddmdachat" devient un LIEN cliquable
    //    vers la fiche de la demande d'achat.
    pc.getChampByName("iddmdachat").setLien(
        lien + "?but=facturefournisseur/dmdachat/dmdachat-arbiochem-fiche.jsp",
        "id="
    );

    // ═══════════════════════════════════════════════════════════════
    // BLOC 5 — MASQUER LES CHAMPS TECHNIQUES
    // ═══════════════════════════════════════════════════════════════
    pc.getChampByName("etatlib").setVisible(false);      // on garde "etat" à la place
    pc.getChampByName("idTraite").setVisible(false);     // technique
    pc.getChampByName("traite").setLibelle("Livraison"); // renommé
    pc.getChampByName("idDevise").setVisible(false);     // on garde idDeviselib
    pc.getChampByName("fournisseur").setVisible(false);  // on garde fournisseurlib
    pc.getChampByName("modepaiement").setVisible(false);// on garde modepaiementlib

    // ═══════════════════════════════════════════════════════════════
    // BLOC 6 — VARIABLES DE NAVIGATION (pour les boutons)
    // ═══════════════════════════════════════════════════════════════
    String pageActuel = "bondecommande/bondecommande-arbiochem-fiche.jsp";   // cette page
    String pageModif  = "bondecommande/bondecommande-arbiochem-saisie.jsp";  // page de modif
    String classe     = "faturefournisseur.As_BonDeCommande";                // FQN de la classe

    // ═══════════════════════════════════════════════════════════════
    // BLOC 7 — GESTION DES ONGLETS (tabs)
    //
    // Un Map sert à marquer UN onglet comme "active" (celui sélectionné).
    // Le paramètre d'URL ?tab=... indique lequel est actif.
    // ═══════════════════════════════════════════════════════════════
    Map<String, String> map = new HashMap<String, String>();

    // Liste des onglets possibles (tous désactivés par défaut)
    map.put("inc/bondecommande-liste-detail", "");   // Détails
    map.put("inc/as-bondelivraison", "");             // Détails de réception
    map.put("inc/achat-cpl-visee", "");               // Rapprochement
    map.put("inc/details-facture", "");               // Facture fournisseur
    map.put("inc/facturation-multiple", "");          // Facturation multiple

    // Lecture du paramètre ?tab=
    String tab = request.getParameter("tab");
    if (tab == null) {
      tab = "inc/bondecommande-liste-detail";         // onglet par défaut
    }

    // Marque l'onglet sélectionné comme "active"
    map.put(tab, "active");

    // Ajoute l'extension .jsp pour l'inclusion plus bas
    tab = tab + ".jsp";

    // Récupère l'objet métier chargé
    As_BonDeCommandeCpl bc = (As_BonDeCommandeCpl) pc.getBase();

    // ⭐ L'ÉTAT du BC — sert à décider QUELS boutons afficher
    int etat = bc.getEtat();
%>

<%-- ═══════════════════════════════════════════════════════════════
     PARTIE HTML
     ═══════════════════════════════════════════════════════════════ --%>
<div class="content-wrapper">

  <%-- Titre avec flèche retour vers la liste --%>
  <h1 class="box-title">
    <a href="<%= lien + "?but=bondecommande/bondecommande-arbiochem-liste.jsp"%>">
      <i class="fa fa-angle-left"></i>
    </a>
    <%= pc.getTitre() %>
  </h1>

  <div class="row m-0">
    <div class="col-md-3"></div>
    <div class="col-md-6">
      <div class="box-fiche">
        <div class="box">
          <div class="box-body">

            <%-- ⭐ AFFICHE L'EN-TÊTE : tous les champs réglés au BLOC 4 --%>
            <% out.println(pc.getHtml()); %>

            <br/>

            <%-- ═══════════════════════════════════════════════════════════════
                 BLOC 8 — LES BOUTONS D'ACTION (le cœur de la fiche)

                 ⭐ RÈGLE : les boutons changent SELON L'ÉTAT du BC :
                   - état < 11  → Viser, Modifier, Annuler
                   - état >= 11 → Acompte, Réceptionner, Facture
                 ═══════════════════════════════════════════════════════════════ --%>
            <div class="box-footer">

              <%-- ═══ CAS 1 : BC NON VALIDÉ (etat < 11) ═══ --%>
              <% if (etat < 11) { %>

                <%-- Bouton VISER : passe l'état à 11 (valider) --%>
                <a class="btn btn-primary pull-right"
                   href="<%= (String) session.getValue("lien") + "?but=apresTarif.jsp&acte=valider&id=" + request.getParameter("id") + "&bute=bondecommande/bondecommande-arbiochem-fiche.jsp&classe=" + classe %>"
                   style="margin-right: 10px">Viser</a>

                <%-- Bouton MODIFIER : ouvre le formulaire de saisie en mode update --%>
                <a class="btn btn-secondary pull-right"
                   href="<%= lien + "?but=" + pageModif + "&id=" + id + "&acte=update" %>"
                   style="margin-right: 10px">Modifier</a>

                <%-- Bouton ANNULER : passe l'état à 0 --%>
                <a class="btn btn-danger pull-left"
                   href="<%= (String) session.getValue("lien") + "?but=apresTarif.jsp&acte=annuler&id=" + request.getParameter("id") + "&bute=bondecommande/bondecommande-arbiochem-fiche.jsp&classe=" + classe %>">Annuler</a>

              <% } %>

              <%-- ═══ CAS 2 : BC VALIDÉ (etat >= 11) ═══ --%>
              <% if (etat >= 11) { %>

                <%-- Bouton ACOMPTE : saisir un acompte de caisse --%>
                <a style="margin-left: 8px;" class="btn btn-secondary pull-right"
                   href="<%= (String) session.getValue("lien") + "?but=caisse/mvt/mvtCaisse-saisie-sortie.jsp&idf=" + bc.getFournisseur() + "&idbc=" + request.getParameter("id") + "&idModePaiement=" + pc.getChampByName("modepaiement").getValeur() + "&action=acompte" %>">Acompte</a>

                <%-- Bouton RÉCEPTIONNER : ouvre la saisie de bon de livraison --%>
                <a class="btn btn-primary pull-right"
                   href="<%= (String) session.getValue("lien") + "?but=bondelivraison/bondelivraison-arbiochem-saisie.jsp&id=" + request.getParameter("id") %>"
                   style="margin-right: 10px">R&eacute;ceptionner</a>

                <%-- Bouton FACTURE : ouvre la saisie de facture fournisseur --%>
                <a class="btn btn-secondary pull-right"
                   href="<%= (String) session.getValue("lien") + "?but=facturefournisseur/facturefournisseur-saisie.jsp&idbc=" + pc.getChampByName("id").getValeur() %>"
                   style="margin-right: 10px">Insertion Facture Fournisseur</a>

              <% } %>

              <%-- Bouton IMPRIMER : appel au servlet ExportPDFARBIOCHEM --%>
              <a class="btn btn-tertiary pull-right"
                 href="${pageContext.request.contextPath}/ExportPDFARBIOCHEM?action=fiche_bc&id=<%= request.getParameter("id") %>"
                 style="margin-right: 10px">Imprimer</a>

            </div>
            <br/>
          </div>
        </div>
      </div>
    </div>
  </div>

  <%-- ═══════════════════════════════════════════════════════════════
       BLOC 9 — LES ONGLETS (tabs)
       Chaque onglet pointe vers la même page avec ?tab=...
       Le contenu est INCLUS via <jsp:include>.
       ═══════════════════════════════════════════════════════════════ --%>
  <div class="row m-0">
    <div class="col-md-12 nopadding">
      <div class="nav-tabs-custom">

        <%-- La barre des onglets --%>
        <ul class="nav nav-tabs">

          <%-- Onglet Détails (par défaut) --%>
          <li class="<%= map.get("inc/bondecommande-liste-detail") %>">
            <a href="<%= lien %>?but=<%= pageActuel %>&id=<%= id %>&tab=inc/bondecommande-liste-detail">Détails</a>
          </li>

          <%-- Onglet Détails de réception --%>
          <li class="<%= map.get("inc/as-bondelivraison") %>">
            <a href="<%= lien %>?but=<%= pageActuel %>&id=<%= id %>&tab=inc/as-bondelivraison">D&eacute;tails de r&eacute;ception</a>
          </li>

          <%-- Onglet Rapprochement --%>
          <li class="<%= map.get("inc/achat-cpl-visee") %>">
            <a href="<%= lien %>?but=<%= pageActuel %>&id=<%= id %>&tab=inc/achat-cpl-visee">Rapprochement</a>
          </li>

          <%-- Onglet Facture fournisseur --%>
          <li class="<%= map.get("inc/details-facture") %>">
            <a href="<%= lien %>?but=<%= pageActuel %>&id=<%= id %>&tab=inc/details-facture">Facture fournisseur</a>
          </li>

          <%-- Onglet Facturation multiple --%>
          <li class="<%= map.get("inc/facturation-multiple") %>">
            <a href="<%= lien %>?but=<%= pageActuel %>&id=<%= id %>&tab=inc/facturation-multiple">Facturation multiple</a>
          </li>

        </ul>

        <%-- Le contenu de l'onglet actif (inclus dynamiquement) --%>
        <div class="tab-content">
          <%-- ⭐ INCLUSION de l'onglet sélectionné (ex. inc/bondecommande-liste-detail.jsp) --%>
          <jsp:include page="<%= tab %>">
            <jsp:param name="idFactureFournisseur" value="<%= id %>" />
          </jsp:include>
        </div>

      </div>
    </div>
  </div>
</div>

<%-- ═══════════════════════════════════════════════════════════════
     BLOC 10 — CATCH FINAL (pattern APJ)
     ═══════════════════════════════════════════════════════════════ --%>
<%
  } catch (Exception e) {
    e.printStackTrace();
  }
%>