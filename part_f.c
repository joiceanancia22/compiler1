#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    char *in = (argc > 1) ? argv[1] : "input.txt";
    char cmd[256];

    printf("==========================================\n");
    printf("   INTEGRATED COMPILER PIPELINE (PART F)  \n");
    printf("==========================================\n\n");

    system("lex part_a.l && gcc lex.yy.c -o part_a");
    system("yacc -d part_b.y && lex part_b.l && gcc y.tab.c lex.yy.c -o part_b");
    system("yacc -d part_c.y && lex part_c.l && gcc y.tab.c lex.yy.c -o part_c");
    system("gcc part_d.c -o part_d");
    system("gcc part_e.c -o part_e");

    sprintf(cmd, "./part_a < %s", in); system(cmd); printf("\n");
    sprintf(cmd, "./part_b < %s", in); if (system(cmd) != 0) return 1; printf("\n");
    sprintf(cmd, "./part_c < %s > tac.txt", in); system(cmd); system("cat tac.txt"); printf("\n");
    system("./part_d < tac.txt > opt_tac.txt && cat opt_tac.txt"); printf("\n");
    system("./part_e < opt_tac.txt");
    return 0;
}
