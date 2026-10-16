package vente.stat;

import bean.CGenUtil;
import bean.ClassMAPTable;
import ferme.lot.Lot;
import ferme.programme.ProgrammeZootechnique;
import ferme.programme.ProgrammeZootechniqueDetails;
import ferme.triageBatiment.TriageLotSexeQualiteLib;
import ferme.utils.ConstanteFerme;
import utilitaire.UtilDB;
import utilitaire.Utilitaire;
import vente.CaJournalier;

import java.sql.Connection;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * PoussinJourDetail : grille mensuelle du NOMBRE DE POUSSINS OBTENUS par date.
 * Miroir de CaJourDetail (même grille : lignes = JOURSEMAINE, colonnes = mois,
 * lignes TOTAL + MOYENNE) mais la case contient une quantité prévisionnelle
 * au lieu d'un montant CA.
 *
 * Formule (documentée, réglable via les 3 constantes ci-dessous) :
 *   pour chaque lot actif, pour chaque date de ponte D :
 *     oeufs(D)   = pondeuses(lot) * ponteHebdo(ageSemaine, souche) / 100 / 7
 *     eclosion   = D + DUREE_INCUBATION_JOURS
 *     poussins   = oeufs * fertilite / 100 * tauxEclosion / 100
 *   cumulés par date d'éclosion, tous lots confondus.
 * Hypothèses : pontehebdomadaire/fertilite/tauxeclosion sont des %.
 */
public class PoussinJourDetail extends ClassMAPTable {

    /** Durée d'incubation standard poule (jours). A ajuster par souche si besoin. */
    public static final int DUREE_INCUBATION_JOURS = 21;
    /** Nombre de mois affichés : mois courant + suivants. */
    public static final int NB_MOIS = 3;
    /** Marge amont : on simule les pontes jusqu'à 60 jours avant pour remplir le 1er mois. */
    public static final int MARGE_PONTE_JOURS = 60;

    private static final String[] MOIS_FR = {"", "Janvier", "Février", "Mars", "Avril", "Mai", "Juin",
            "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"};

    private int qte;
    private int jour, annee, mois;
    private String jourlib, idjoursemaine;

    public int getQte() { return qte; }
    public void setQte(int qte) { this.qte = qte; }

    public int getJour() { return jour; }
    public void setJour(int jour) { this.jour = jour; }

    public int getAnnee() { return annee; }
    public void setAnnee(int annee) { this.annee = annee; }

    public int getMois() { return mois; }
    public void setMois(int mois) { this.mois = mois; }

    public String getJourlib() { return jourlib; }
    public void setJourlib(String jourlib) { this.jourlib = jourlib; }

    public String getIdjoursemaine() { return idjoursemaine; }
    public void setIdjoursemaine(String idjoursemaine) { this.idjoursemaine = idjoursemaine; }

    @Override
    public String getAttributIDName() { return ""; }

    @Override
    public String getTuppleID() { return ""; }

    /**
     * Grille mois x jours-semaine, même structure que CaJourDetail.getAllOptimised().
     * Clé = "Moislib Année" (ex "Octobre 2026"), valeur = tableau
     * [lignes JOURSEMAINE + TOTAL + MOYENNE].
     */
    public Map<String, PoussinJourDetail[]> getPrevisionsParMois() throws Exception {
        Map<String, PoussinJourDetail[]> result = new LinkedHashMap<>();
        Connection conn = null;
        try {
            conn = new UtilDB().GetConn();

            // Lignes de la grille : entrées JOURSEMAINE (semaineDuMois x jour), comme le CA.
            CaJourSemaine[] jours = (CaJourSemaine[]) CGenUtil.rechercher(new CaJourSemaine(), null, null, conn, "");

            // Mois affichés : courant + suivants.
            List<int[]> moisAffiches = new ArrayList<int[]>();
            Calendar cal = Calendar.getInstance();
            for (int k = 0; k < NB_MOIS; k++) {
                moisAffiches.add(new int[]{cal.get(Calendar.MONTH) + 1, cal.get(Calendar.YEAR)});
                cal.add(Calendar.MONTH, 1);
            }

            // Prévision globale une seule fois : date éclosion -> qte (tous lots).
            Map<String, Double> previsions = this.calculerPrevisions(conn, moisAffiches);

            for (int[] ma : moisAffiches) {
                int mois = ma[0];
                int annee = ma[1];

                PoussinJourDetail[] tab = new PoussinJourDetail[jours.length + 2];
                double total = 0;
                int nombre = 0;
                for (int i = 0; i < jours.length; i++) {
                    CaJourSemaine j = jours[i];
                    PoussinJourDetail d = new PoussinJourDetail();
                    d.setMois(mois);
                    d.setAnnee(annee);
                    d.setIdjoursemaine(j.getId());
                    d.setJourlib(j.getLibjour());
                    d.setJour(0);
                    // La date calendaire portée par cette ligne : quantième jour du mois
                    // dont (semaineDuMois, jourSemaine) correspond à l'entrée.
                    int quantieme = quantiemeDeLigne(mois, annee, j.getNumsemaine(), j.getNumjour());
                    if (quantieme > 0) {
                        d.setJour(quantieme);
                        double q = previsions.getOrDefault(cleDate(annee, mois, quantieme), 0.0);
                        d.setQte((int) Math.round(q));
                    }
                    if (d.getQte() > 0) {
                        nombre++;
                    }
                    tab[i] = d;
                    total += d.getQte();
                    if (i == jours.length - 1) {
                        PoussinJourDetail dT = new PoussinJourDetail();
                        dT.setMois(mois);
                        dT.setAnnee(annee);
                        dT.setJourlib("TOTAL poussins");
                        dT.setQte((int) Math.round(total));
                        tab[i + 1] = dT;
                        PoussinJourDetail dM = new PoussinJourDetail();
                        dM.setMois(mois);
                        dM.setAnnee(annee);
                        dM.setJourlib("Moyenne poussins/jour");
                        dM.setQte(nombre > 0 ? (int) Math.round(total / nombre) : 0);
                        tab[i + 2] = dM;
                        break;
                    }
                }
                result.put(MOIS_FR[mois] + " " + annee, tab);
            }
            return result;
        } finally {
            if (conn != null) conn.close();
        }
    }

    /**
     * Coeur prévision : simule les pontes passées+futures de chaque lot actif
     * et cumule les poussins par date d'éclosion (clé "aaaa-m-j").
     * Ne couvre que les dates d'éclosion dans les mois affichés.
     */
    private Map<String, Double> calculerPrevisions(Connection conn, List<int[]> moisAffiches) throws Exception {
        Calendar debut = Calendar.getInstance();
        debut.set(moisAffiches.get(0)[1], moisAffiches.get(0)[0] - 1, 1, 0, 0, 0);
        debut.add(Calendar.DAY_OF_YEAR, -MARGE_PONTE_JOURS);
        Calendar fin = Calendar.getInstance();
        int[] dernier = moisAffiches.get(moisAffiches.size() - 1);
        fin.set(dernier[1], dernier[0] - 1, 1, 0, 0, 0);
        fin.set(Calendar.DAY_OF_MONTH, fin.getActualMaximum(Calendar.DAY_OF_MONTH));
        return previsionsEclosions(conn, debut, fin,
                debutEclosionMin(moisAffiches), finEclosionMax(moisAffiches));
    }

    /**
     * Même calcul sur une fenêtre explicite (réutilisé par PoussinCalendrier).
     * @param debutPonte 1er jour de ponte simulé (borne incluse).
     * @param finPonte dernier jour de ponte simulé (borne incluse).
     * @param debutEclosionMs borne basse des éclosions gardées (ms).
     * @param finEclosionMs borne haute des éclosions gardées (ms).
     * @return date d'éclosion "aaaa-m-j" -> poussins cumulés tous lots.
     */
    public Map<String, Double> previsionsEclosions(Connection conn, Calendar debutPonte,
            Calendar finPonte, long debutEclosionMs, long finEclosionMs) throws Exception {
        Map<String, Double> cumul = new LinkedHashMap<String, Double>();

        // Lots actifs = date de clôture nulle.
        Lot[] lots = (Lot[]) CGenUtil.rechercher(new Lot(), null, null, conn, " AND datecloture IS NULL");
        for (Lot lot : lots) {
            if (lot.getDatearrivee() == null) continue;

            // Effectif de pondeuses = femelles conformes disponibles du lot.
            double pondeuses = dispoFemelles(lot.getId(), conn);
            if (pondeuses <= 0) continue;

            // Normes de la souche : via le programme du lot, sinon 1er programme de la souche.
            String idProgramme = lot.getIdprogramme();
            if (idProgramme == null || idProgramme.trim().isEmpty()) {
                idProgramme = programmeDeSouche(lot.getIdSouche(), conn);
            }
            if (idProgramme == null) continue;
            ProgrammeZootechniqueDetails[] normes =
                    (ProgrammeZootechniqueDetails[]) CGenUtil.rechercher(
                            new ProgrammeZootechniqueDetails(), null, null, conn,
                            " AND idmere='" + idProgramme.replace("'", "''") + "' AND idsexe='"
                                    + ConstanteFerme.IDSEXEFEMELLE + "'");

            // Simulation jour par jour.
            Calendar d = (Calendar) debutPonte.clone();
            while (!d.after(finPonte)) {
                int ageSemaines = (int) ((d.getTimeInMillis() - lot.getDatearrivee().getTime())
                        / (7L * 24 * 60 * 60 * 1000));
                if (ageSemaines >= 0) {
                    ProgrammeZootechniqueDetails norme = normePourAge(normes, ageSemaines);
                    if (norme != null && norme.getPontehebdomadaire() > 0) {
                        double oeufs = pondeuses * norme.getPontehebdomadaire() / 100.0 / 7.0;
                        double poussins = oeufs * norme.getFertilite() / 100.0
                                * norme.getTauxeclosion() / 100.0;
                        Calendar eclosion = (Calendar) d.clone();
                        eclosion.add(Calendar.DAY_OF_YEAR, DUREE_INCUBATION_JOURS);
                        long t = eclosion.getTimeInMillis();
                        if (t >= debutEclosionMs && t <= finEclosionMs) {
                            String cle = cleDate(eclosion.get(Calendar.YEAR),
                                    eclosion.get(Calendar.MONTH) + 1,
                                    eclosion.get(Calendar.DAY_OF_MONTH));
                            cumul.put(cle, cumul.getOrDefault(cle, 0.0) + poussins);
                        }
                    }
                }
                d.add(Calendar.DAY_OF_YEAR, 1);
            }
        }
        return cumul;
    }

    /** Femelles conformes disponibles d'un lot (vue des dispos + libellés). */
    private double dispoFemelles(String idLot, Connection conn) throws Exception {
        TriageLotSexeQualiteLib t = new TriageLotSexeQualiteLib();
        t.setIdLot(idLot);
        t.setIdSexe(ConstanteFerme.IDSEXEFEMELLE);
        t.setIdQualite(ConstanteFerme.qualiteConforme);
        TriageLotSexeQualiteLib[] r =
                (TriageLotSexeQualiteLib[]) CGenUtil.rechercher(t, null, null, conn, "");
        if (r != null && r.length > 0) return r[0].getQte();
        return 0;
    }

    /** 1er programme zootechnique de la souche (secours si le lot n'en a pas). */
    private String programmeDeSouche(String idSouche, Connection conn) throws Exception {
        if (idSouche == null || idSouche.trim().isEmpty()) return null;
        ProgrammeZootechnique p = new ProgrammeZootechnique();
        p.setIdsouche(idSouche.trim());
        ProgrammeZootechnique[] r =
                (ProgrammeZootechnique[]) CGenUtil.rechercher(p, null, null, conn, "");
        if (r != null && r.length > 0) return r[0].getId();
        return null;
    }

    /** Norme d'âge : ligne exacte, sinon la plus proche en dessous, sinon rien. */
    private ProgrammeZootechniqueDetails normePourAge(ProgrammeZootechniqueDetails[] normes, int ageSemaines) {
        if (normes == null) return null;
        ProgrammeZootechniqueDetails best = null;
        int bestAge = -1;
        for (ProgrammeZootechniqueDetails n : normes) {
            int a;
            try {
                a = Integer.parseInt(n.getAge() == null ? "" : n.getAge().trim());
            } catch (NumberFormatException ex) {
                continue;
            }
            if (a == ageSemaines) return n;
            if (a < ageSemaines && a > bestAge) {
                bestAge = a;
                best = n;
            }
        }
        return best;
    }

    /** Quantieme du mois pour (semaineDuMois, jourSemaine 1=lundi..7=dimanche), -1 si inexistant. */
    private int quantiemeDeLigne(int mois, int annee, int numsemaine, int numjour) {
        Calendar c = Calendar.getInstance();
        c.set(annee, mois - 1, 1);
        int max = c.getActualMaximum(Calendar.DAY_OF_MONTH);
        for (int jour = 1; jour <= max; jour++) {
            c.set(annee, mois - 1, jour);
            int sem = (jour - 1) / 7 + 1;
            // Calendar : dimanche=1..samedi=7 -> convertir en lundi=1..dimanche=7.
            int wd = c.get(Calendar.DAY_OF_WEEK);
            int num = wd == Calendar.SUNDAY ? 7 : wd - 1;
            if (sem == numsemaine && num == numjour) return jour;
        }
        return -1;
    }

    private String cleDate(int annee, int mois, int jour) {
        return annee + "-" + mois + "-" + jour;
    }

    private long debutEclosionMin(List<int[]> moisAffiches) {
        int[] premier = moisAffiches.get(0);
        Calendar c = Calendar.getInstance();
        c.set(premier[1], premier[0] - 1, 1, 0, 0, 0);
        c.set(Calendar.MILLISECOND, 0);
        return c.getTimeInMillis();
    }

    private long finEclosionMax(List<int[]> moisAffiches) {
        int[] dernier = moisAffiches.get(moisAffiches.size() - 1);
        Calendar c = Calendar.getInstance();
        c.set(dernier[1], dernier[0] - 1, 1, 23, 59, 59);
        c.set(Calendar.DAY_OF_MONTH, c.getActualMaximum(Calendar.DAY_OF_MONTH));
        return c.getTimeInMillis();
    }
}
