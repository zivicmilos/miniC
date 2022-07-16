//RETURN: 25

int main() {
	int a, b, c;
	a = 5;
	b = 6;
	c = 1;
	
	check(a) {
		when 1: a++; 
		when 5: a = a + 2; break;
		when 6: a = a + 3;
	}
	
	check(b) {
		when 1: b++; break;
		when 5: b = b + 2; break;
		when 6: b = b + 3;
		otherwise: b = b + 4;
	}
	
	check(c) {
		when 2: c++; 
		when 5: c = c + 2; break;
		when 6: c = c + 3;
		otherwise: c = c + 4;
	}
	
	return a + b + c;
}
