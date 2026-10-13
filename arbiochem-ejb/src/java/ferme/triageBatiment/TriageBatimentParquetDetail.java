package ferme.triageBatiment;

import bean.ClassFille;
import java.sql.Connection;

public class TriageBatimentParquetDetail extends ClassFille {
    private String id;
    private String idmere;
    private String idbatiment;
    private String idparquet;
    private String idsexe;
    private String idqualite;
    private int qte;

    /**
     * Etat de sante : 10 = sain, 1..9 = malade. Aucun mort au triage.
     * Defaut = 10 (sain) si l'utilisateur ne choisit rien.
     * En int (pas Integer) : APJ ne sait pas mapper un Integer
     * (getTypeColonne() null -> NullPointerException dans la recherche paginee).
     */
    private int etatsante = 10;

    /** Remarque libre sur la ligne de repartition. */
    private String remarque;

    /**
     * Capacite max du parquet, saisie au triage (le batiment est ignore).
     * En double (pas Double) pour APJ.
     */
    private double capmax;

    public double getCapmax() {
        return capmax;
    }

    public void setCapmax(double capmax) {
        this.capmax = capmax;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getIdmere() {
        return idmere;
    }

    public void setIdmere(String idmere) {
        this.idmere = idmere;
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

    public String getIdsexe() {
        return idsexe;
    }

    public void setIdsexe(String idsexe) {
        this.idsexe = idsexe;
    }

    public String getIdqualite() {
        return idqualite;
    }

    public void setIdqualite(String idqualite) {
        this.idqualite = idqualite;
    }

    public int getQte() {
        return qte;
    }

    public void setQte(int qte) {
        this.qte = qte;
    }

    // ═══════════════════════════════════════════════════════════════
    //  ETAT DE SANTE  —  controle unitaire
    // ═══════════════════════════════════════════════════════════════

    /**
     * @param etatsante 1 (malade) ... 10 (sain).
     * Pas d'exception ici : le setter sert aussi a relire l'historique (0 = mort).
     * Le controle 1..10 est fait a la saisie (TriageBatimentParquet.checkLigne).
     */
    public void setEtatsante(int etatsante) {
        this.etatsante = etatsante;
    }

    public int getEtatsante() {
        return etatsante;
    }

    public String getRemarque() {
        return remarque;
    }

    public void setRemarque(String remarque) {
        this.remarque = remarque;
    }


    @Override
    public String getNomClasseMere() {
        return "ferme.triageBatiment.TriageBatimentParquet";
    }

    @Override
    public String getLiaisonMere() {
        return "idmere";
    }

    public TriageBatimentParquetDetail() throws Exception {
        this.setNomTable("TRIAGEBATIMENTPARQUETDETAIL");
        this.setNomClasseMere("ferme.triageBatiment.TriageBatimentParquet");
        this.setLiaisonMere("idmere");
    }

    @Override
    public void construirePK(Connection c) throws Exception {
        this.preparePk("TBD","getseq_triagebatparquetdetail");
        this.setId(makePK(c));
    }

    @Override
    public String getTuppleID() {
        return id;
    }

    @Override
    public String getAttributIDName() {
        return "id";
    }
}

