//RETURN: 10

int main() {
	int a;
	a = 5;
	
	check(a) {
		when 1: a++; 
		when 5: a = a + 2;
		when 6: a = a + 3;
	}
	
	return a;
}
