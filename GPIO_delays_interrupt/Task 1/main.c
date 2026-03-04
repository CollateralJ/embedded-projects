/*
 * DA1_C.c
 *
 * Created: 2/23/2025 10:28:39 PM
 * Author : CollateralJ
 */ 

#include <avr/io.h>
#include <cstdint>
using namespace std;



void tea_encrypt(uint32_t k[4], uint32_t text[2]) {
	uint32_t y = text[0], z = text[1];
	uint32_t delta = 0x9e3779b9, sum = 0;
	int n;
	for (n = 0; n < 32; n++) {
		sum += delta;
		y += ((z << 4) + k[0]) ^ (z + sum) ^ ((z >> 5) + k[1]);
		z += ((y << 4) + k[2]) ^ (y + sum) ^ ((y >> 5) + k[3]);
	}
	text[0] = y;
	text[1] = z;
}

int main(){
	uint32_t k[4] = {0x476f6f64, 0x456e6f75, 0x6768466f, 0x724d6521};
	uint32_t text1[2] = {0x54686973, 0x20697320};
	tea_encrypt(k, text1);
	uint32_t text2[2] = {0x6d792073, 0x616d706c};
	tea_encrypt(k, text2);
	uint32_t text3[2] = {0x6520636f, 0x64652066};
	tea_encrypt(k, text3);
	uint32_t text4[2] = {0x6f722044, 0x65736967};
	tea_encrypt(k, text4);
	uint32_t text5[2] = {0x6e204173, 0x7369676e};
	tea_encrypt(k, text5);
	uint32_t text6[2] = {0x6d656e74, 0x20312e20};
	tea_encrypt(k, text6);
	uint32_t text7[2] = {0x50657266, 0x6563746c};
	tea_encrypt(k, text7);
	uint32_t text8[2] = {0x7920696e, 0x74616374};
	tea_encrypt(k, text8);

	while (1){
		
	}
		
	return 0;
}