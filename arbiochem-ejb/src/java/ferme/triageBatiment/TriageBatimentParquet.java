package ferme.triageBatiment;

import bean.ClassMAPTable;
import bean.ClassMere;
import ferme.utils.ConstanteFerme;
import ferme.utils.ControlePoussin;
import bean.CGenUtil;
import utilitaire.ConstanteEtat;

import java.sql.Connection;
import java.sql.Date;
import java.util.LinkedHashMap;
import java.util.Map;
import utilitaire.UtilDB;

public class TriageBatimentParquet extends ClassMere {
    private String id;
    private Date daty;
    private String idlot;
    private int dispomale;
    private int dispofemelle,etat;
    /** Disponible TOTAL a repartir (vivants usine - deja reparti), calcule en Java. */
    private double dispo;

    public double getDispo() {
        return dispo;
    }

    public void setDispo(double dispo) {
        this.dispo = dispo;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public Date getDaty() {
        return daty;
    }

    public void setDaty(Date daty) {
        this.daty = daty;
    }

    public String getIdlot() {
        return idlot;
    }

    public void setIdlot(String idlot) {
        this.idlot = idlot;
    }

    public int getEtat() {
        return etat;
    }

    public void setEtat(int etat) {
        this.etat = etat;
    }

    public int getDispomale() {
        return dispomale;
    }

    public void setDispomale(int dispomale) {
        this.dispomale = dispomale;
    }

    public int getDispofemelle() {
        return dispofemelle;
    }

    public void setDispofemelle(int dispofemelle) {
        this.dispofemelle = dispofemelle;
    }



    public TriageBatimentParquet() throws Exception {
        this.setNomTable("TRIAGEBATIMENTPARQUET");
        this.setNomClasseFille("ferme.triageBatiment.TriageBatimentParquetDetail");
        this.setLiaisonFille("idmere");
    }

    @Override
    public void construirePK(Connection c) throws Exception {
        this.preparePk("TB","getseq_triagebatimentparquet");
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

    // ═══════════════════════════════════════════════════════════════
    //  CONTROLES  —  repartition des VIVANTS de l'usine en parquets
    //
    //  C'est ICI que le sexe apparait. Chaque ligne = un parquet d'un
    //  batiment, un sexe (male / femelle), un etat de sante (10 = sain,
    //  1..9 = malade) et une quantite. Aucun mort au triage.
    // ═══════════════════════════════════════════════════════════════

    @Override
    public ClassMAPTable createObject(String u, Connection c) throws Exception {
        // « Modifier » repasse par ici : remplacer les lignes au lieu de les doubler
        ControlePoussin.preparerModification("TRIAGEBATIMENTPARQUET", "TRIAGEBATIMENTPARQUETDETAIL", "idmere", this.getId(), c);
        TriageBatimentParquetDetail[] lignes = (TriageBatimentParquetDetail[]) this.getFille();
        controler(lignes, c);
        return super.createObject(u, c);
    }

    /**
     * A la validation on rejoue les controles sur ce qui est en base
     * (un autre triage a pu remplir un parquet entre-temps).
     *
     * L'ecran n'envoie que l'id : on recharge d'abord le triage, car
     * ClassEtat.validerObject() reecrit tout l'enregistrement a partir de this.
     */
    @Override
    public Object validerObject(String u, Connection c) throws Exception {
        TriageBatimentParquet enBase = (TriageBatimentParquet) new TriageBatimentParquet()
                .getById(this.getId(), "TRIAGEBATIMENTPARQUET", c);
        if (enBase == null) {
            throw new Exception("Le triage " + this.getId() + " n'existe pas.");
        }
        this.setDaty(enBase.getDaty());
        this.setIdlot(enBase.getIdlot());
        this.setDispo(enBase.getDispo());
        this.setDispomale(enBase.getDispomale());
        this.setDispofemelle(enBase.getDispofemelle());
        this.setEtat(enBase.getEtat());

        TriageBatimentParquetDetail[] lignes =
                (TriageBatimentParquetDetail[]) this.getFille(null, c, "");
        controler(lignes, c);

        return super.validerObject(u, c);
    }

    /**
     * Tous les controles de la repartition, puis le calcul du disponible.
     * Le batiment est ignore : un compartiment = un parquet.
     *   1. le lot est obligatoire
     *   2. checkAntecedent : le lot a une reception usine validee
     *   3. chaque ligne : parquet, capacite max > 0, sexe, etat de sante 1..10, qte > 0
     *   4. un parquet = une seule capacite max (meme valeur sur toutes ses lignes)
     *   5. checkParquet    : pas d'autre lot dans le parquet (triages valides)
     *   6. checkCapParquet : deja occupe + places <= capacite max saisie
     *   7. checkSomme      : places <= vivants usine - deja reparti
     */
    public void controler(TriageBatimentParquetDetail[] lignes, Connection c) throws Exception {
        if (this.getIdlot() == null || this.getIdlot().trim().isEmpty()) {
            throw new Exception("Le lot est obligatoire.");
        }
        double dispo = calculerDispo(c);

        // par parquet : quantite placee (un parquet peut avoir plusieurs lignes) et capacite max
        Map<String, Double> parParquet = new LinkedHashMap<String, Double>();
        Map<String, Double> capParquet = new LinkedHashMap<String, Double>();
        double total = 0;
        if (lignes != null) {
            for (TriageBatimentParquetDetail d : lignes) {
                checkLigne(d);
                d.setIdqualite(ConstanteFerme.qualiteConforme);   // que des vivants
                String p = d.getIdparquet();
                Double cap = capParquet.get(p);
                if (cap != null && Math.abs(cap - d.getCapmax()) > ControlePoussin.EPSILON) {
                    throw new Exception("Le parquet " + p + " a deux capacités max différentes ("
                            + cap + " et " + d.getCapmax() + ").");
                }
                capParquet.put(p, d.getCapmax());
                Double deja = parParquet.get(p);
                parParquet.put(p, (deja == null ? 0 : deja) + d.getQte());
                total += d.getQte();
            }
        }
        if (total <= ControlePoussin.EPSILON) {
            throw new Exception("Saisissez au moins une ligne de répartition.");
        }

        for (Map.Entry<String, Double> e : parParquet.entrySet()) {
            double occupe = ControlePoussin.checkParquet(e.getKey(), this.getIdlot(), this.getId(), c);
            ControlePoussin.checkCapParquet(e.getKey(), capParquet.get(e.getKey()), occupe, e.getValue());
        }

        ControlePoussin.checkSomme(dispo, total,
                "le disponible du lot " + this.getIdlot() + " (vivants usine - déjà réparti)");
        this.setDispo(dispo);
    }

    /** Une ligne : parquet, capacite max > 0, sexe male / femelle, etat de sante 1..10, qte > 0. */
    public static void checkLigne(TriageBatimentParquetDetail d) throws Exception {
        if (d.getIdparquet() == null || d.getIdparquet().trim().isEmpty()) {
            throw new Exception("Le parquet est obligatoire sur chaque ligne.");
        }
        if (d.getCapmax() <= 0) {
            throw new Exception("La capacité max du parquet " + d.getIdparquet()
                    + " est obligatoire (> 0).");
        }
        if (!ConstanteFerme.IDSEXEMALE.equals(d.getIdsexe())
                && !ConstanteFerme.IDSEXEFEMELLE.equals(d.getIdsexe())) {
            throw new Exception("Le sexe (mâle / femelle) est obligatoire sur chaque ligne.");
        }
        if (d.getEtatsante() < 1 || d.getEtatsante() > 10) {
            throw new Exception("L'état de santé doit être entre 1 (malade) et 10 (sain) : "
                    + "il n'y a plus de morts au triage.");
        }
        if (d.getQte() <= 0) {
            throw new Exception("La quantité d'une ligne doit être supérieure à 0.");
        }
    }

    /**
     * Disponible a repartir = vivants de la reception usine validee
     *                         - deja place par les AUTRES triages valides du lot.
     */
    public double calculerDispo(Connection c) throws Exception {
        double vivantsUsine = ControlePoussin.checkReceptionUsine(this.getIdlot(), c);
        return vivantsUsine - getDejaReparti(c);
    }

    /** Total deja place dans des parquets par les AUTRES triages valides de ce lot. */
    public double getDejaReparti(Connection c) throws Exception {
        String sauf = (this.getId() != null) ? " and m.id <> '" + this.getId() + "'" : "";
        Object o = CGenUtil.rechercherSimple(
                "select nvl(sum(d.qte),0) from TRIAGEBATIMENTPARQUETDETAIL d"
              + " join TRIAGEBATIMENTPARQUET m on d.idmere = m.id"
              + " where m.idlot = '" + this.getIdlot() + "'"
              + " and m.etat >= " + ConstanteEtat.getEtatValider() + sauf, c);
        return (o instanceof Number) ? ((Number) o).doubleValue() : 0;
    }

    /** Disponible d'un lot pour l'ecran de saisie (connexion ouverte si c == null). */
    public double getDispoLot(String idLot, Connection c) throws Exception {
        boolean canClose = false;
        try {
            if (c == null) {
                c = new UtilDB().GetConn();
                canClose = true;
            }
            this.setIdlot(idLot);
            return calculerDispo(c);
        } finally {
            if (canClose && c != null) {
                c.close();
            }
        }
    }

    public double getDisponnible(String idLot,String idSexe,Connection c)throws Exception{
        boolean canClose=false;
        try{
            if(c==null){
                c=new UtilDB().GetConn();
                canClose=true;
            }
            TriageLotSexeQualite t = new TriageLotSexeQualite();
            t.setIdLot(idLot);
            t.setIdsexe(idSexe);
            t.setIdqualite(ConstanteFerme.qualiteConforme);
            TriageLotSexeQualite[] r = (TriageLotSexeQualite[])CGenUtil.rechercher(t, null, null, c, "");
            if(r.length>0 && r!=null){
                return r[0].getQte();
            }
            return 0;
        } catch(Exception e){
            throw e;
        } finally {
            if(canClose){
                c.close();
            }
        }
    }

    public double getDisponnibleLib(String idLot,String idSexe, String idQualite,Connection c)throws Exception{
        boolean canClose=false;
        try{
            if(c==null){
                c=new UtilDB().GetConn();
                canClose=true;
            }
            TriageLotSexeQualiteLib t = new TriageLotSexeQualiteLib();
            t.setIdLot(idLot);
            t.setIdSexe(idSexe);
            t.setIdQualite(idQualite);
            TriageLotSexeQualiteLib[] r = (TriageLotSexeQualiteLib[])CGenUtil.rechercher(t, null, null, c, "");
            if(r.length>0 && r!=null){
                return r[0].getQte();
            }
            return 0;
        } catch(Exception e){
            throw e;
        } finally {
            if(canClose){
                c.close();
            }
        }
    }
}

