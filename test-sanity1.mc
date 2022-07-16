//OPIS: Sanity check za miniC gramatiku

int f(int x) {
    int y;
    return x + 2 - y;
}

/* U sledecoj funkciji se proverava sintaksa 
		individualnih zadataka
*/

int foo(int x, unsigned y, unsigned z, int i,int x1, unsigned y1, unsigned z1, int i1,int x2) {
	int a;
	unsigned b;
	a = 5;
	b = 2u;
	while (a < x or b < y) {
			while (z < y and b < y)
				y++;
			x = x - 1;
			b = b + 1u;
	}
	
	check (x) {
		when 1: x = x + 1; x = x + 2;
		when 2: x = x + 2; break;
		when 3: x = x + 1; x = x + 3; break;
		otherwise : x++;
	}
	
	y = (z < y or b < y) ? z : y;
	
	if (a > x and z1 < y1 or i != i1)
		return x2;
}

unsigned f2() {
    return 2u;
}

unsigned ff(unsigned x) {
    unsigned y;
    return x + f2() - y;
}

int main() {
    int a; 
    int b;
    int aa;
    int bb;
    int c;
    int d;
    unsigned u;
    unsigned w;
    unsigned uu;
    unsigned ww;

    //poziv funkcije
    a = f(3);
    a = foo(3,3u,3u,3,3,3u,3u,3,3);
    //if iskaz sa else delom
    if (a < b)  //1
        a = 1;
    else
        a = -2;

    if (a + c == b + d - 4) //2
        a = 1;
    else
        a = 2;

    if (u == w) {   //3
        u = ff(1u);
        a = f(11);
    }
    else {
        w = 2u;
    }
    if (a + c == b - d - -4) {  //4
        a = 1;
    }
    else
        a = 2;
    a = f(42);

    if (a + (aa-c) - d < b + (bb-a))    //5
        uu = w-u+uu;
    else
        d = aa+bb-c;

    //if iskaz bez else dela
    if (a < b)  //6
        a = 1;

    if (a + c == b - +4)    //7
        a = 1;
        
    return 0;
}

