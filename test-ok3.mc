int main() {
	int a, b, c;
	
	a = 5;
	b = a;
	c = 10;
	
	while (a < b or c > b) {
		a++;
		
		b = b + a;
	}
	
	check(a) {
		when 5: a++; break;
		when 2: b = c;
		//otherwise: c = a;
	}
	
	return 0;
}
