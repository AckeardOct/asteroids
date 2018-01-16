module asteroid;

import entity;
import colize;
import common;

import std.stdio;

class Asteroid : Entity
{
public:
    this()
    {
        super("data/images/asteroid.png");
        moveTo(Vector2f(Rnd.width, Rnd.height));
        rotate(Rnd.angle());
        accelerate(Rnd.accelerate());                
    }    

    this(Asteroid asteroid)
    {
        super("data/images/asteroid.png");
        moveTo(asteroid.getCenter());        
        rotate(Rnd.angle());
        accelerate(Rnd.accelerate() * 2);
        setSize(asteroid.size / 2);        
    }

    override public
    void colize()
    {
        if(getSize().x > 20)
        {        
            entities.insert(new Asteroid(this));
            entities.insert(new Asteroid(this));
        }
        entities.linearRemoveElement(this); 
    }
}
