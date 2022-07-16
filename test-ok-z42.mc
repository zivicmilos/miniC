//RETURN: 4

int main() {

	int a, b, c;
	a = 5;
	b = 3;
	c = 4;
	
	while (a < b or b < c) 
		b = b + 1;

	return b;
}
