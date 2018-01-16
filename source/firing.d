module firing;

import std.container.slist;
import entity;
import common;
import colize;

import dlib.math.vector;
alias dlib.math.vector.Vector2f V2f;

import std.stdio;

class Bullet : Entity
{
public:
    this(Entity parent)
    {
        super("data/images/bullet.png");            
        direction = parent.getDirection();
        moveTo(parent.getCenter());
        moveBy(parent.getSize().length / 1.5);
        accelerate(300);      
        setSize(V2f(5,5));             
    }

    override public
    bool outMap(AABB one)
    {          
        if(!super.outMap(one))
            return false;      
        entities.linearRemoveElement(this);        
        return true;
    }    
}

class Gun
{  
private:  
    Entity parent = null;

public:    
    public this(Entity parent)
    {
        this.parent = parent;
    }
    
    public Entity fire()
    {        
        return new Bullet(parent);
    }   
}
