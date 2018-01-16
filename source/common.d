module common;

import std.random;
import std.container.slist;
import entity;

const uint WIDTH = 640;
const uint HEIGHT = 480;

SList!Entity entities;        

int getRandom(int max)
{    
    auto RANDOM_GENERATOR = Random(unpredictableSeed);	
	return uniform(0, max, RANDOM_GENERATOR);
}

class Rnd
{
    static
    int width() { return getRandom(WIDTH); }

    static
    int height() { return getRandom(HEIGHT); }    

    static
    int angle() { return getRandom(360); }

    static
    int accelerate() { return getRandom(70) + 10; }

    static
    int asteroidsCount() { return getRandom(10) + 5; }
}


