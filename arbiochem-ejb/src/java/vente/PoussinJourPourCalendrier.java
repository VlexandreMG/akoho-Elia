package vente;

import bean.ClassMAPTable;

/**
 * Une case du calendrier poussins : la quantité prévue à une date.
 * Miroir de CaJourDetailPourCalendrier (montant -> qte).
 */
public class PoussinJourPourCalendrier extends ClassMAPTable {
    String daty;
    int jour, semainemois, mois, annee;
    String jourLib;
    double qte;

    public PoussinJourPourCalendrier() {
    }

    @Override
    public String getTuppleID() {
        return "";
    }

    @Override
    public String getAttributIDName() {
        return "";
    }

    public String getDaty() {
        return daty;
    }

    public void setDaty(String daty) {
        this.daty = daty;
    }

    public int getJour() {
        return jour;
    }

    public void setJour(int jour) {
        this.jour = jour;
    }

    public int getSemainemois() {
        return semainemois;
    }

    public void setSemainemois(int semainemois) {
        this.semainemois = semainemois;
    }

    public int getMois() {
        return mois;
    }

    public void setMois(int mois) {
        this.mois = mois;
    }

    public int getAnnee() {
        return annee;
    }

    public void setAnnee(int annee) {
        this.annee = annee;
    }

    public String getJourLib() {
        return jourLib;
    }

    public void setJourLib(String jourLib) {
        this.jourLib = jourLib;
    }

    public double getQte() {
        return qte;
    }

    public void setQte(double qte) {
        this.qte = qte;
    }
}
