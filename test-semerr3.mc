int main() {
	int a, b;
	
	check(a) {
		when 1: a = a + b; break;
		when 2u: b = a;
		when 3: b = b + 5u;
	}
	
	check(c) {
		when 1: a = a + b; break;
		when 1: a = b; 
		otherwise: a++;
	}
}
