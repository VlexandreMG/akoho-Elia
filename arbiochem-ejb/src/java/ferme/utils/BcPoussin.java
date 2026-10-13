package ferme.utils;

import bean.ClassMAPTable;

/**
 * Lecture de la vue v_bc_poussin : quantite de POUSSINS commandee par bon de commande.
 * Seules les lignes du BC dont le produit est un poussin sont comptees.
 * (sql/01_schema_elevage.sql, section 5.1)
 */
public class BcPoussin extends ClassMAPTable {
    private String idbc;
    private double qtecommande;
    private double montant;
    private double pu;

    public BcPoussin() {
        this.setNomTable("v_bc_poussin");
    }

    @Override
    public String getTuppleID() {
        return idbc;
    }

    @Override
    public String getAttributIDName() {
        return "idbc";
    }

    public String getIdbc() {
        return idbc;
    }

    public void setIdbc(String idbc) {
        this.idbc = idbc;
    }

    public double getQtecommande() {
        return qtecommande;
    }

    public void setQtecommande(double qtecommande) {
        this.qtecommande = qtecommande;
    }

    public double getMontant() {
        return montant;
    }

    public void setMontant(double montant) {
        this.montant = montant;
    }

    public double getPu() {
        return pu;
    }

    public void setPu(double pu) {
        this.pu = pu;
    }
}
