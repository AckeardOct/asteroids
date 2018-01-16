import std.stdio;
import std.conv;

import dsfml.graphics;
alias dsfml.graphics.Vector2f Vector2f;

import entity;
import colize;
import ship;
import asteroid;
import common;

import firing;

int main(string[] args) 
{
    Clock clock = new Clock();
    
    RenderWindow window = new RenderWindow(VideoMode(WIDTH, HEIGHT), "Asteroids");
    
    Ship ship = new Ship("data/images/red.png");
    ship.moveTo(Vector2f(WIDTH / 2, HEIGHT / 2 )); 
            
    for(int i = 0; i < Rnd.asteroidsCount(); i++)        
        entities.insert(new Asteroid());

    Font font = new Font();
    font.loadFromFile("data/fonts/ariali.ttf");
    
    Text text = new Text(); 
    text.setFont(font);
    text.setColor(Color.White);
    text.setCharacterSize(16);

    while(window.isOpen)
    {
        if(clock.getElapsedTime() < dur!("msecs")(33))
            continue;
        int fps = to!(int)(1000 / clock.getElapsedTime().total!("msecs"));
        clock.restart();
        
        Event event;
        while(window.pollEvent(event))
        {
            if(event.type == Event.EventType.Closed)
                window.close();
            else if(event.type == Event.EventType.KeyPressed)
            {
                switch(event.key.code)
                {
                    case Event.key.code.Left:
                        ship.rotate(-30);
                        break;
                    case Event.key.code.Right:
                        ship.rotate(30);
                        break;
                    case Event.key.code.Up:
                        ship.accelerate(10);
                        break;
                    case Event.key.code.Space:
                        ship.fire();                        
                        break;
                    default: break;
                }
            }
        }

                       
        
        ship.calc();
        foreach(entity; entities)
            entity.calc();

        ship.outMap(window.getAABB());
        foreach(entity ; entities)
            entity.outMap(window.getAABB());
        
        foreach(one; entities)
        {                        
            foreach(two; entities)
            {
                if(one != two)
                    resolveColize(one, two);
            }
        }
        
        window.clear(Color.Black);

        if(entities.empty)
            text.setString("WIN!!!");
        
        window.draw(ship);
        foreach(entity ; entities)
            window.draw(entity);
        window.draw(text);
                    
        window.display();

        
    }
    
    writeln("END");
    return 0;        
}

