//RETURN: 7

int main() {
	int a, b, c, d;
	a = 2;
	b = 5;
	c = 9;
	
	c = (a < b and a > c) ? a : b;
	
	d = (a > b or b == c) ? a : b;
	
	return c + d;
}
