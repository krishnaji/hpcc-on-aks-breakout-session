/* https://github.com/hpcc-systems/HPCC-Platform/blob/b4bdebe56a7c40af5631559bb5d9b9581a5604ca/testing/benchmarks/ecl/terasort.ecl */

#option('THOR_ROWCRC', 0); // don/t need individual row CRCs

 

rec := record

      string10  key;

      string10  seq;

      string80  fill;

       end;

 

in := DATASET('hpcconazure::terasort1',rec,FLAT);

OUTPUT(SORT(in,key,UNSTABLE),,'hpcconazure::terasort1out',overwrite);