package ferme.utils;

import bean.ClassMAPTable;

/**
 * Lecture de la vue v_parquet_occupation : un parquet DANS un batiment.
 *   capacite : BATIMENTDETAIL
 *   occupe   : poussins places par les triages VALIDES
 *   reste    = capacite - occupe
 *   nblot / idlot : lot(s) present(s) dans le parquet
 * (sql/01_schema_elevage.sql, section 5.4)
 */
public class ParquetOccupation extends ClassMAPTable {
    private String idbatiment;
    private String idparquet;
    private String idlot;
    private double capacite;
    private double occupe;
    private double reste;
    private int nblot;

    public ParquetOccupation() {
        this.setNomTable("v_parquet_occupation");
    }

    @Override
    public String getTuppleID() {
        return idparquet;
    }

    @Override
    public String getAttributIDName() {
        return "idparquet";
    }

    public String getIdbatiment() {
        return idbatiment;
    }

    public void setIdbatiment(String idbatiment) {
        this.idbatiment = idbatiment;
    }

    public String getIdparquet() {
        return idparquet;
    }

    public void setIdparquet(String idparquet) {
        this.idparquet = idparquet;
    }

    public String getIdlot() {
        return idlot;
    }

    public void setIdlot(String idlot) {
        this.idlot = idlot;
    }

    public double getCapacite() {
        return capacite;
    }

    public void setCapacite(double capacite) {
        this.capacite = capacite;
    }

    public double getOccupe() {
        return occupe;
    }

    public void setOccupe(double occupe) {
        this.occupe = occupe;
    }

    public double getReste() {
        return reste;
    }

    public void setReste(double reste) {
        this.reste = reste;
    }

    public int getNblot() {
        return nblot;
    }

    public void setNblot(int nblot) {
        this.nblot = nblot;
    }
}
