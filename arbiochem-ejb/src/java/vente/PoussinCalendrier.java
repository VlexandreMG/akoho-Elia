package vente;

import utilitaire.UtilDB;
import utilitaire.Utilitaire;
import vente.stat.PoussinJourDetail;

import java.sql.Connection;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.TextStyle;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Moteur du calendrier poussins : même structure que CaCalendrier
 * (jours 1..31, mois, totaux), mais les cases viennent de la prévision
 * PoussinJourDetail au lieu de CA_JOUR_DETAILS_CA.
 */
public class PoussinCalendrier {
    String[] listeMois;
    HashMap<String, Map<String, List<PoussinJourPourCalendrier>>> caMensuels;
    String[] listeDate;
    int[] jours;
    HashMap<String, Double[]> total = new HashMap<>();

    public PoussinCalendrier(String dtMin, String dtMax) throws Exception {
        Connection c = null;
        try {
            c = new UtilDB().GetConn();
            this.jours = new int[31];
            for (int i = 0; i < 31; i++) {
                jours[i] = i + 1;
            }
            this.setListeDate(dtMin, dtMax);
            this.setCaMensuels(c);
            this.setTotal();
        } catch (Exception e) {
            throw e;
        } finally {
            if (c != null) c.close();
        }
    }

    public int[] getJours() {
        return jours;
    }

    public void setJours(int[] jours) {
        this.jours = jours;
    }

    public String[] getListeDate() {
        return listeDate;
    }

    public void setListeDate(String dtMin, String dtMax) {
        int day = Utilitaire.diffJourDaty(dtMax, dtMin);
        String liste[] = new String[day];
        for (int i = 0; i < day; i++) {
            liste[i] = Utilitaire.formatterDaty(Utilitaire.ajoutJourDate(dtMin, i));
        }
        this.listeDate = liste;
    }

    public HashMap<String, Map<String, List<PoussinJourPourCalendrier>>> getCaMensuels() {
        return caMensuels;
    }

    public void setCaMensuels(HashMap<String, Map<String, List<PoussinJourPourCalendrier>>> caMensuels) {
        this.caMensuels = caMensuels;
    }

    /**
     * Remplit mois x jours depuis la prévision (au lieu du SELECT CA).
     * Seules les dates à qté > 0 créent une entrée (comme le CA).
     */
    public void setCaMensuels(Connection c) throws Exception {
        DateTimeFormatter inputFormat = DateTimeFormatter.ofPattern("dd/MM/yyyy", Locale.FRANCE);
        this.caMensuels = new LinkedHashMap<String, Map<String, List<PoussinJourPourCalendrier>>>();

        // Fenêtre de pontes : 60 jours avant le 1er jour affiché.
        LocalDate debut = LocalDate.parse(listeDate[0], inputFormat);
        LocalDate fin = LocalDate.parse(listeDate[listeDate.length - 1], inputFormat);
        Calendar debutPonte = Calendar.getInstance();
        debutPonte.set(debut.getYear(), debut.getMonthValue() - 1, debut.getDayOfMonth(), 0, 0, 0);
        debutPonte.add(Calendar.DAY_OF_YEAR, -PoussinJourDetail.MARGE_PONTE_JOURS);
        Calendar finPonte = Calendar.getInstance();
        finPonte.set(fin.getYear(), fin.getMonthValue() - 1, fin.getDayOfMonth(), 23, 59, 59);

        Calendar borneBasse = Calendar.getInstance();
        borneBasse.set(debut.getYear(), debut.getMonthValue() - 1, debut.getDayOfMonth(), 0, 0, 0);
        Calendar borneHaute = Calendar.getInstance();
        borneHaute.set(fin.getYear(), fin.getMonthValue() - 1, fin.getDayOfMonth(), 23, 59, 59);

        Map<String, Double> previsions = new PoussinJourDetail().previsionsEclosions(
                c, debutPonte, finPonte,
                borneBasse.getTimeInMillis(), borneHaute.getTimeInMillis());

        for (Map.Entry<String, Double> e : previsions.entrySet()) {
            if (e.getValue() == null || e.getValue() <= 0) continue;
            // Clé "aaaa-m-j" -> date du calendrier.
            String[] parts = e.getKey().split("-");
            LocalDate date = LocalDate.of(Integer.parseInt(parts[0]),
                    Integer.parseInt(parts[1]), Integer.parseInt(parts[2]));
            String dateStr = date.format(inputFormat);
            String cleMois = date.getMonth().getDisplayName(TextStyle.FULL, Locale.FRANCE)
                    + " " + date.getYear();
            String cleJour = String.valueOf(date.getDayOfMonth());
            PoussinJourPourCalendrier cell = new PoussinJourPourCalendrier();
            cell.setDaty(dateStr);
            cell.setJour(date.getDayOfMonth());
            cell.setSemainemois((date.getDayOfMonth() - 1) / 7 + 1);
            cell.setMois(date.getMonthValue());
            cell.setAnnee(date.getYear());
            String jourLib = date.getDayOfWeek().getDisplayName(TextStyle.FULL, Locale.FRANCE);
            cell.setJourLib(jourLib.substring(0, 1).toUpperCase() + jourLib.substring(1));
            cell.setQte(e.getValue());
            caMensuels.putIfAbsent(cleMois, new HashMap<String, List<PoussinJourPourCalendrier>>());
            caMensuels.get(cleMois).putIfAbsent(cleJour, new ArrayList<PoussinJourPourCalendrier>());
            caMensuels.get(cleMois).get(cleJour).add(cell);
        }

        // Tous les mois de la période existent, même vides (anti-NPE JSP).
        this.listeMois = genererTousLesMois();
        for (String mois : listeMois) {
            if (!caMensuels.containsKey(mois)) {
                caMensuels.put(mois, new HashMap<String, List<PoussinJourPourCalendrier>>());
            }
        }
    }

    private String[] genererTousLesMois() {
        if (listeDate == null || listeDate.length == 0) {
            return new String[]{};
        }
        DateTimeFormatter inputFormat = DateTimeFormatter.ofPattern("dd/MM/yyyy", Locale.FRANCE);
        LinkedHashMap<String, Boolean> moisMap = new LinkedHashMap<>();
        LocalDate debut = LocalDate.parse(listeDate[0], inputFormat);
        LocalDate fin = LocalDate.parse(listeDate[listeDate.length - 1], inputFormat);
        LocalDate courant = debut;
        while (!courant.isAfter(fin)) {
            String cleMois = courant.getMonth().getDisplayName(TextStyle.FULL, Locale.FRANCE)
                    + " " + courant.getYear();
            moisMap.putIfAbsent(cleMois, true);
            courant = courant.plusMonths(1).withDayOfMonth(1);
        }
        return moisMap.keySet().toArray(new String[]{});
    }

    public void setTotal() {
        // total[0] - Qté totale ; total[1] - Moyenne.
        this.total = new HashMap<>();
        for (String dt : listeMois) {
            double qteTotal = 0;
            double moyenne = 0;
            int count = 0;
            Map<String, List<PoussinJourPourCalendrier>> lignes = this.caMensuels.get(dt);
            for (Map.Entry<String, List<PoussinJourPourCalendrier>> entry : lignes.entrySet()) {
                List<PoussinJourPourCalendrier> v = entry.getValue();
                if (v != null) {
                    for (PoussinJourPourCalendrier res : v) {
                        qteTotal += res.getQte();
                    }
                    count += v.size();
                }
            }
            if (count > 0) {
                moyenne = qteTotal / count;
            }
            total.put(dt, new Double[]{qteTotal, moyenne});
        }
    }

    public HashMap<String, Double[]> getTotal() {
        return total;
    }

    public String[] getListeMois() {
        return listeMois;
    }

    public void setListeMois(String[] listeMois) {
        this.listeMois = listeMois;
    }

    public PoussinJourPourCalendrier[] getReservationByTime(int jour, String mois) throws Exception {
        List<PoussinJourPourCalendrier> res = this.caMensuels.get(mois).get(String.valueOf(jour));
        if (res == null) {
            return null;
        }
        return res.toArray(new PoussinJourPourCalendrier[]{});
    }
}
