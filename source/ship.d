module ship;

import entity;
import firing;
import common;

class Ship : Entity
{
private:
    Gun gun;
    
    public
    this(string imagePath)
    {
        super(imagePath);
        gun = new Gun(this);
    }

    public
    void fire()
    {         
       entities.insert(gun.fire());
    }
}
