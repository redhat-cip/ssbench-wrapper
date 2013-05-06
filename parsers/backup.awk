BEGIN { total="false"; create="false"; read="false"; update="false"; del="false" }
/^TOTAL/    { total="true"; create="false"; read="false"; update="false"; del="false";}
/^READ/    { total="false"; create="false"; read="true"; update="false"; del="false";}
/^CREATE/    { total="false"; create="true"; read="false"; update="false"; del="false";}
/^UPDATE/    { total="false"; create="false"; read="false"; update="true"; del="false";}
/^DELETE/    { total="false"; create="false"; read="false"; update="false"; del="true";}
/Count/    { if (total=="true") opt=$NF;
             else if (read=="true") opr=$NF;
             else if (create=="true") opc=$NF;
             else if (update=="true") opu=$NF;
             else if (del=="true") opd=$NF;
           }
/Last-byte/ && /Large files objs/ {
             if (total=="true") tlfo=$6;
             else if (read=="true") rlfo=$6;
             else if (create=="true") clfo=$6;
             else if (update=="true") ulfo=$6;
             else if (del=="true") dlfo=$6;
}
/Last-byte/ && /Small files objs/ {
             if (total=="true") tsfo=$6;
             else if (read=="true") rsfo=$6;
             else if (create=="true") csfo=$6;
             else if (update=="true") usfo=$6;
             else if (del=="true") dsfo=$6;
}
/Last-byte/ && /Medium files objs/ {
             if (total=="true") tmfo=$6;
             else if (read=="true") rmfo=$6;
             else if (create=="true") cmfo=$6;
             else if (update=="true") umfo=$6;
             else if (del=="true") dmfo=$6;
}
END { print "Compute results in CSV file";
      header="total"
      if (opc>0) header = header",create";
      if (opr>0) header = header",read";
      if (opu>0) header = header",update";
      if (opd>0) header = header",delete";
      print header > ENVIRON["WORKSPACE"]"/backup-ops.csv";
      print opt","opc","opr","opu","opd >> ENVIRON["WORKSPACE"]"/backup-ops.csv";
      print "Small object,Medium Object,Large object" > ENVIRON["WORKSPACE"]"/backup-total-ops-details.csv"
      print tsfo","tmfo","tlfo >> ENVIRON["WORKSPACE"]"/backup-total-ops-details.csv"
      print "Small object,Medium Object,Large object" > ENVIRON["WORKSPACE"]"/backup-read-ops-details.csv"
      print rsfo","rmfo","rlfo >> ENVIRON["WORKSPACE"]"/backup-read-ops-details.csv"
      print "Small object,Medium Object,Large object" > ENVIRON["WORKSPACE"]"/backup-create-ops-details.csv"
      print csfo","cmfo","clfo >> ENVIRON["WORKSPACE"]"/backup-create-ops-details.csv"
      print "Small object,Medium Object,Large object" > ENVIRON["WORKSPACE"]"/backup-update-ops-details.csv"
      print usfo","umfo","ulfo >> ENVIRON["WORKSPACE"]"/backup-update-ops-details.csv"
      print "Small object,Medium Object,Large object" > ENVIRON["WORKSPACE"]"/backup-delete-ops-details.csv"
      print dsfo","dmfo","dlfo >> ENVIRON["WORKSPACE"]"/backup-delete-ops-details.csv"
    }
