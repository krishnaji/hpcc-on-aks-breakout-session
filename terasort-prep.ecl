/* https://github.com/krishnaji/HPCC-AZURE/blob/main/prep.ecl */

#option('thorConnectTimeout', 1720000);
unsigned8 numrecs := 10000000000/CLUSTERSIZE : stored('numrecs');   // rows per node
rec := record
      string10  key;
      string10  seq;
      string80  fill;
       end;
seed := dataset([{'0', '0', '0'}], rec);
rec addNodeNum(rec L, unsigned4 c) := transform
    SELF.seq := (string) (c-1);
    SELF := L;
  END;
one_per_node := distribute(normalize(seed, CLUSTERSIZE, addNodeNum(LEFT, COUNTER)), (unsigned) seq);
rec fillRow(rec L, unsigned4 c) := transform
    SELF.key := (>string1<)(RANDOM()%95+32)+
                (>string1<)(RANDOM()%95+32)+
                (>string1<)(RANDOM()%95+32)+
                (>string1<)(RANDOM()%95+32)+
                (>string1<)(RANDOM()%95+32)+
                (>string1<)(RANDOM()%95+32)+
                (>string1<)(RANDOM()%95+32)+
                (>string1<)(RANDOM()%95+32)+
                (>string1<)(RANDOM()%95+32)+
                (>string1<)(RANDOM()%95+32);
    unsigned4 n := ((unsigned4)L.seq)*numrecs+c;
    SELF.seq := (string10)n;
    unsigned4 cc := (n-1)*8;
    string1 c1 := (>string1<)((cc)%26+65);
    string1 c2 := (>string1<)((cc+1)%26+65);
    string1 c3 := (>string1<)((cc+2)%26+65);
    string1 c4 := (>string1<)((cc+3)%26+65);
    string1 c5 := (>string1<)((cc+4)%26+65);
    string1 c6 := (>string1<)((cc+5)%26+65);
    string1 c7 := (>string1<)((cc+6)%26+65);
    string1 c8 := (>string1<)((cc+7)%26+65);
    SELF.fill := c1+c1+c1+c1+c1+c1+c1+c1+c1+c1+
             c2+c2+c2+c2+c2+c2+c2+c2+c2+c2+
             c3+c3+c3+c3+c3+c3+c3+c3+c3+c3+
             c4+c4+c4+c4+c4+c4+c4+c4+c4+c4+
             c5+c5+c5+c5+c5+c5+c5+c5+c5+c5+
             c6+c6+c6+c6+c6+c6+c6+c6+c6+c6+
             c7+c7+c7+c7+c7+c7+c7+c7+c7+c7+
             c8+c8+c8+c8+c8+c8+c8+c8+c8+c8;
  END;
outdata := NORMALIZE(one_per_node, numrecs, fillRow(LEFT, counter));
OUTPUT(outdata,,'hpcconazure::terasort1',overwrite);
