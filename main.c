/*
 * 3b run c.c
 *
 * Created: 15/09/2022 8:25:36 PM
 * Author : 61481
 */ 

#include <avr/io.h>
#define F_CPU 12000000UL
#include <util/delay.h>

#define ddrKeypad DDRC
#define portKeypad PORTC
#define pinKeypad PINC
#define ddrLed DDRB
#define portLed PORTB
#define pinLed PINB

// global variables
uint8_t temp, temp2, output = 0x00, flag = 0;   // 0 - just 1 key, 1 - 1st key for password entry, 2 - 2nd key for password entry
uint8_t colIdle = 0xff;

uint8_t cols[] = {0xef, 0xdf, 0xbf, 0x7f};

uint8_t table[] = {	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255,		13, 255, 255, 255, 12, 255, 11, 10, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255,		15, 255, 255, 255, 9, 255, 6, 3, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
					255, 255, 255, 255, 255, 255, 255,		0, 255, 255, 255, 8, 255, 5, 2,  255,
					255, 255, 255, 255, 255, 255, 255,		14, 255, 255, 255, 7, 255, 4, 1, 255,
					255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255};
					
uint8_t passcode[] = {1, 2, 3, 4, 5, 6};
uint8_t passcodeInput[6];

void triggerStrobe() {
	for (uint8_t i=0; i<10; i++) {
		PORTB ^= (1<<4);						// toggle strobe LED on and off 5 times
		_delay_ms(100);							// 5Hz delay
	}
}

void triggerZone(uint8_t zone, uint8_t prevZones) {
	if (flag == 0) {
		PORTB ^= (1<<5);								// turn on the siren LED ( PORTB || 0x20 )
		flag = 1;
	}
	
	triggerStrobe();							// blink strobe light at 5Hz for 5 times
	PORTB &= 0xF0;
	PORTB |= (prevZones >> 4);
	
	PORTB ^= (1<<zone);								// turn on the triggered Zone LED
	
	output = PINB;
}

void errorBlink() {
	uint8_t t = PINB;
	
	for (uint8_t i=0; i<2; i++) {
		PORTB = 0x00;
		_delay_ms(1000);
		PORTB = 0xFF;
		_delay_ms(1000);
	}
	
	if (flag == 0) {
		t &= 0xF0;
	}
	
	PORTB = t;
}

void passblink() {
	PORTB &= 0x0F;
	PORTB |= output;
	_delay_ms(50);
}

void released() {
	temp = PINC;
	while (temp == temp2) {
		temp = PINC;
	}
}

void colFound() {
	released();
	
	output = *(table+temp2);
	PORTB &= 0xF0;
	PORTB |= output;
}

void ReadKP() {
	for (uint8_t i=0; i<4; i++) {
		temp = cols[i];
		PORTC = temp;
		_delay_ms(50);
		temp2 = PINC;
		if (temp != temp2) { colFound(); return; }
		
		if (i == 3) { i = -1; }
	}
}

void enterNewPasscode() {
	for (uint8_t i=0; i < 6; i++) {						// loop 6 times to read 6 digits of passcode
		ReadKP();
		
		if (output>9) { errorBlink(); return; }			// if in disarmed state, and any zone keys or */# is pressed
			
		passcodeInput[i] = output;
	}
	
	for (uint8_t i=0; i < 6; i++) {
		passcode[i] = passcodeInput[i];
	}
	
	_delay_ms(5000);
}

void passcodeVerification(uint8_t stateFlg) {
	for (uint8_t i=0; i<6; i++) {
		if (passcode[i] != passcodeInput[i]) {
			errorBlink();
			return;
		}
	}
	
	flag = 0;
	
	if (stateFlg == 0) {
		_delay_ms(3000);
		output = 0x40;									// turn on the armed state LED
		PORTB = output;									// armed state
		return;
	}
	
	output = 0x80;										// turn on the disarmed state LED
	PORTB = output;										// disarmed state
}

void passcodeEntry(uint8_t state) {
	for (uint8_t i=0; i < 6; i++) {						// loop 6 times to read 6 digits of passcode
		uint8_t t = (PINB<<4);
		ReadKP();
		
		if (state == 0) {
			
			if (output == 15) {
				enterNewPasscode();
				output = 0x40;
				PORTB = output;
				return;
			}
			
			if (output > 9) { 				
				output = 0x80;
				PORTB = output;   // disarmed state 
				return;
			}
		}
		
		if (state == 1) {								// if in armed state, check if any zone keys are pressed ( A, B, C, D )
			switch (output) {
				case 10:
					triggerZone(0, t);
					return;
				case 11:
					triggerZone(1, t);
					return;
				case 12:
					triggerZone(2, t);
					return;
				case 13:
					triggerZone(3, t);
					return;
			}
		}
		
		passcodeInput[i] = output;
	}
	
	passcodeVerification(state);		// verify passcode with change state flag of disarmed state
}

int main(void)
{	
	DDRB = 0xFF;	// all pins output
	DDRC = 0xF0;	// first 4 bits output and last 4 bits input
	PORTC = 0x0F;    // setting pull up resistors for rows
	
	temp = colIdle;
	PORTC = temp;		// setting columns to idle
	
	temp = PINC;
	output = 0x80;
	PORTB = output;   // disarmed state
	
	while (1) {
		output = PINB;
		
		if (output == 0x80) {				// is in disarmed state
			passcodeEntry(0);				// ask to enter passcode and store it in passcodeEntry Array
			continue;
		}
		
		if (output >= 0x40) {
			passcodeEntry(1);				// ask to enter passcode and store it in passcodeEntry Array
			continue;
		}
	}
	
	while (1);
}
