package ferme.utils;

import bean.CGenUtil;
import bean.ClassEtat;
import faturefournisseur.As_BonDeCommande;
import ferme.receptionaeroport.ReceptionAeroportBilan;
import ferme.receptionaeroport.ReceptionPoussinAeroport;
import ferme.receptionusine.ReceptionUsineLib;
import java.sql.Connection;
import utilitaire.ConstanteEtat;

/**
 * Controles communs a toutes les etapes du flux poussin :
 *
 *   BC -> reception aeroport -> reception usine -> repartition en parquets
 *
 *   checkSomme       : ce qui est saisi ne depasse pas ce qui est attendu
 *                      (la somme de l'etape precedente)
 *   checkAntecedent  : l'etape precedente existe et est validee
 *   checkLignePerte  : une ligne de perte est un MORT ou un PERDU, qte > 0
 *   checkBcPoussin   : le bon de commande existe, est valide, contient des poussins
 *   checkReceptionAeroport : le lot a une reception aeroport validee (-> vivants)
 *   checkReceptionUsine    : le lot a une reception usine validee (-> vivants)
 *   checkParquet     : le parquet n'a pas d'autre lot (le batiment est ignore)
 *   checkCapParquet  : occupe + ajoute <= capacite max saisie au triage
 */
public class ControlePoussin {

    /** Tolerance pour comparer des quantites en double (pas de != sur des double). */
    public static final double EPSILON = 0.0001;

    /**
     * La somme saisie ne doit pas depasser la somme attendue.
     *
     * @param attendu  la somme de reference (commande, vivants de l'etape precedente)
     * @param saisi    la somme des lignes saisies (morts + perdus, ou total reparti)
     * @param libelle  ce que represente l'attendu, pour le message d'erreur
     */
    public static void checkSomme(double attendu, double saisi, String libelle) throws Exception {
        if (attendu <= EPSILON) {
            throw new Exception("Aucune quantité attendue : " + libelle + " vaut 0.");
        }
        if (saisi < -EPSILON) {
            throw new Exception("La quantité saisie ne peut pas être négative (" + saisi + ").");
        }
        if (saisi - attendu > EPSILON) {
            throw new Exception("La quantité saisie (" + saisi + ") dépasse "
                    + libelle + " (" + attendu + ").");
        }
    }

    /**
     * L'etape precedente doit exister et au moins un de ses enregistrements doit etre valide.
     *
     * @param antecedents les enregistrements de l'etape precedente
     * @param libelle     le nom de l'etape precedente, pour le message d'erreur
     */
    public static void checkAntecedent(ClassEtat[] antecedents, String libelle) throws Exception {
        if (antecedents == null || antecedents.length == 0) {
            throw new Exception("Introuvable : " + libelle + ". Faites d'abord l'étape précédente.");
        }
        for (ClassEtat a : antecedents) {
            if (a.getEtat() >= ConstanteEtat.getEtatValider()) {
                return;
            }
        }
        throw new Exception("Pas encore validé : " + libelle + ". Validez d'abord l'étape précédente.");
    }

    /** Une ligne de perte : qualite MORT ou PERDU, quantite strictement positive. */
    public static void checkLignePerte(String idQualite, double qte) throws Exception {
        if (!ConstanteFerme.qualiteMort.equals(idQualite)
                && !ConstanteFerme.qualitePerdu.equals(idQualite)) {
            throw new Exception("Une ligne de perte doit être MORT ou PERDU.");
        }
        if (qte <= EPSILON) {
            throw new Exception("La quantité d'une ligne de perte doit être supérieure à 0.");
        }
    }

    /**
     * Le bon de commande doit exister, etre valide et contenir des poussins.
     *
     * @return la quantite de poussins commandee
     */
    public static double checkBcPoussin(String idbc, Connection c) throws Exception {
        if (idbc == null || idbc.trim().isEmpty()) {
            throw new Exception("Le bon de commande est obligatoire.");
        }
        As_BonDeCommande[] bc = (As_BonDeCommande[]) CGenUtil.rechercher(
                new As_BonDeCommande(), null, null, c, " and id = '" + idbc + "'");
        if (bc.length == 0) {
            throw new Exception("Le bon de commande " + idbc + " n'existe pas.");
        }
        checkAntecedent(bc, "bon de commande " + idbc);

        double qteCommande = getQteCommandePoussin(idbc, c);
        if (qteCommande <= EPSILON) {
            throw new Exception("Le bon de commande " + idbc + " ne contient aucun poussin.");
        }
        return qteCommande;
    }

    /** Quantite de poussins commandee sur un BC (vue v_bc_poussin), 0 si aucune. */
    public static double getQteCommandePoussin(String idbc, Connection c) throws Exception {
        BcPoussin[] r = (BcPoussin[]) CGenUtil.rechercher(
                new BcPoussin(), null, null, c, " and idbc = '" + idbc + "'");
        return (r.length > 0) ? r[0].getQtecommande() : 0;
    }

    /**
     * Le lot doit avoir une reception aeroport validee.
     *
     * @return les vivants a l'aeroport (somme des receptions validees du lot)
     */
    public static double checkReceptionAeroport(String idlot, Connection c) throws Exception {
        ReceptionPoussinAeroport[] rpa = (ReceptionPoussinAeroport[]) CGenUtil.rechercher(
                new ReceptionPoussinAeroport(), null, null, c,
                " and idlot = '" + idlot + "' and etat > 0");
        checkAntecedent(rpa, "réception aéroport du lot " + idlot);

        ReceptionAeroportBilan[] b = (ReceptionAeroportBilan[]) CGenUtil.rechercher(
                new ReceptionAeroportBilan(), null, null, c,
                " and idlot = '" + idlot + "' and etat >= " + ConstanteEtat.getEtatValider());
        double vivants = 0;
        for (ReceptionAeroportBilan r : b) {
            vivants += r.getNbvivant();
        }
        return vivants;
    }

    /**
     * Le lot doit avoir une reception usine validee.
     *
     * @return les vivants a l'usine (somme des receptions validees du lot)
     */
    public static double checkReceptionUsine(String idlot, Connection c) throws Exception {
        ReceptionUsineLib[] ru = (ReceptionUsineLib[]) CGenUtil.rechercher(
                new ReceptionUsineLib(), null, null, c,
                " and idlot = '" + idlot + "' and etat > 0");
        checkAntecedent(ru, "réception usine du lot " + idlot);

        double vivants = 0;
        for (ReceptionUsineLib r : ru) {
            if (r.getEtat() >= ConstanteEtat.getEtatValider()) {
                vivants += r.getNbvivant();
            }
        }
        return vivants;
    }

    /**
     * Le parquet ne doit contenir aucun AUTRE lot : un parquet = un seul lot a la fois.
     * Le batiment est ignore. On ne compte que les triages VALIDES, hors le triage courant.
     *
     * @param idTriage le triage en cours (exclu du calcul), null a la creation
     * @return ce qui est deja place dans le parquet (pour checkCapParquet)
     */
    public static double checkParquet(String idparquet, String idlot, String idTriage, Connection c)
            throws Exception {
        if (idparquet == null || idparquet.trim().isEmpty()) {
            throw new Exception("Le parquet est obligatoire.");
        }
        String depuis = " from TRIAGEBATIMENTPARQUETDETAIL d"
                + " join TRIAGEBATIMENTPARQUET m on d.idmere = m.id"
                + " where d.idparquet = '" + idparquet + "'"
                + " and m.etat >= " + ConstanteEtat.getEtatValider()
                + (idTriage != null ? " and m.id <> '" + idTriage + "'" : "");

        Object autre = CGenUtil.rechercherSimple(
                "select max(m.idlot)" + depuis + " and m.idlot <> '" + idlot + "'", c);
        if (autre != null && !autre.toString().trim().isEmpty()) {
            throw new Exception("Le parquet " + idparquet + " est déjà occupé par le lot " + autre
                    + ". Un parquet ne contient qu'un seul lot.");
        }

        Object occupe = CGenUtil.rechercherSimple("select nvl(sum(d.qte),0)" + depuis, c);
        return (occupe instanceof Number) ? ((Number) occupe).doubleValue() : 0;
    }

    /**
     * La capacite max du parquet, saisie au triage, ne doit pas etre depassee.
     *
     * @param capmax  capacite max saisie sur la ligne de triage
     * @param occupe  deja place par les autres triages valides (checkParquet)
     * @param ajoute  ce qu'on veut y placer avec ce triage
     */
    public static void checkCapParquet(String idparquet, double capmax, double occupe, double ajoute)
            throws Exception {
        if (occupe + ajoute - capmax > EPSILON) {
            throw new Exception("Capacité dépassée pour le parquet " + idparquet
                    + " : capacité max " + capmax + ", déjà occupé " + occupe
                    + ", à placer " + ajoute + " (reste " + (capmax - occupe) + ").");
        }
    }

    /**
     * « Modifier » un document du flux (reception aeroport, reception usine, triage).
     *
     * Les ecrans de saisie renvoient toujours acte=insert : en modification, APJ met a jour
     * l'en-tete (id deja connu) mais REINSERE toutes les lignes avec de nouveaux id
     * -> lignes en double. On supprime donc d'abord les anciennes lignes : modifier =
     * remplacer les lignes. Interdit si le document est deja valide.
     *
     * Sans effet a la creation (id vide ou absent de la base).
     */
    public static void preparerModification(String tableMere, String tableFille, String colMere,
            String id, Connection c) throws Exception {
        if (id == null || id.trim().isEmpty()) {
            return;
        }
        Object etat = CGenUtil.rechercherSimple(
                "select max(etat) from " + tableMere + " where id = '" + id + "'", c);
        if (!(etat instanceof Number)) {
            return;                                    // pas encore en base : creation
        }
        if (((Number) etat).intValue() >= ConstanteEtat.getEtatValider()) {
            throw new Exception("Le document " + id + " est déjà validé : modification impossible.");
        }
        java.sql.Statement st = c.createStatement();
        try {
            st.executeUpdate("delete from " + tableFille + " where " + colMere + " = '" + id + "'");
        } finally {
            st.close();
        }
    }
}
