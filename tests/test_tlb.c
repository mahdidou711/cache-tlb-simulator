#include <stdio.h>
#include <assert.h>
#include "tlb.h"

int main(void) {
  /* 1. Boucle sur 6 configurations */
  int count = 0;
  LOOP_TLB_CONFIG {
    inittlb();
    assert(tsets == tsize / tway);
    assert(am == 0 && dtlb == 0);
    count++;
  }
  assert(count == 6);

  /* 2. Init, meme page et LRU (tsize=8, tway=2 => tsets=4) */
  tsize = 8;
  tway = 2;
  inittlb();

  ac(0);   assert(dtlb == 1); /* page 0 : defaut */
  ac(512); assert(dtlb == 1); /* page 0 : succes (meme page de 1024 o) */

  ac(4 * pagesize); assert(dtlb == 2); /* page 4 (ensemble 0) : defaut */
  ac(0);            assert(dtlb == 2); /* page 0 : succes -> page 4 devient LRU */
  ac(8 * pagesize); assert(dtlb == 3); /* page 8 (ensemble 0) : defaut, evince page 4 */

  ac(0);            assert(dtlb == 3); /* page 0 toujours en TLB -> succes */
  ac(4 * pagesize); assert(dtlb == 4); /* page 4 a ete evincee -> defaut */

  printf("Tous les tests TLB ont reussi (6 configs, init, meme page, LRU) !\n");
  return 0;
}