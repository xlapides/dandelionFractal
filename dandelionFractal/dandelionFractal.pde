float accelerateInterpolator(float f, float m) {
  return constrain(pow(f, m), 0, 1);
}

float overshootInterpolator(float f, float tension) {
  return (tension + 1) * pow(f - 1, 3) + tension * pow(f - 1, 2) + 1;
}
 
boolean triggerWind = false;

color tracerColour = color(255, 255, 200, 60);

PVector wind = new PVector(16, -5);

int maxSplits = 3;
int tracersPerSplit = 7;

float thickness = 2;
float nodeSize = 8;
float glowScale = 8;
float glowOpacity = 10;
float minSpeed = 200;
float maxSpeed = 300;
float minDuration = 0.4;
float maxDuration = 0.6;

int minDelay = 120;
int maxDelay = 180;


ArrayList<Tracer> tracers = new ArrayList();

void init() {
  triggerWind = false;
  tracers.clear();
  tracers.add(new Tracer(width/2, height, -HALF_PI, random(minSpeed, maxSpeed), random(minDuration, maxDuration), 0));
}

void setup() {
  size(800, 800, P2D);
  strokeWeight(thickness);
  init();
}

void draw() {
  background(0);
  int done = 0;
  for (int i = 0; i<tracers.size(); i++) {
    Tracer t = tracers.get(i);
    if(t.outOfBounds()) {
        tracers.remove(t);
        i -= 1;
        continue;
    }
    done += int(t.state == Tracer.STATE_WAITING);
    if(triggerWind && t.state != Tracer.STATE_BLOWING) {
      t.state = Tracer.STATE_BLOWING;
    }
    if (!t.alive && t.state != Tracer.STATE_WAITING) {
      t.split(tracers);
    }
    t.update();
    t.draw();
  }
  if (!triggerWind) {
    triggerWind = done == tracers.size() && tracers.size() > 0;
  }
}

void keyReleased() {
  if (key == 'c') {
    init();
  }
}

class Tracer {

  private static final int STATE_TRACING = 0;
  private static final int STATE_WAITING = 1;
  private static final int STATE_BLOWING = 2;
  private static final int STATE_DONE = 3;

  int state = STATE_TRACING;

  PVector pos, start, vel, off = new PVector();
  float duration;
  int splits;
  float time = 0;
  boolean isSplit = false;
  boolean alive = true;

  int delay;

  Node node = null;

  public Tracer(float x, float y, float a, float s, float duration, int splits) {
    this(new PVector(x, y), new PVector(cos(a) * s, sin(a) * s), duration, splits);
  }

  public Tracer(PVector pos, PVector vel, float duration, int splits) {
    this.pos = new PVector(pos.x, pos.y);
    this.start = new PVector(pos.x, pos.y);
    this.vel = vel;
    this.duration = duration;
    this.splits = splits;
    float d = map(constrain(height - pos.y, 0, height), height, 0, minDelay, maxDelay);
    delay = random(d * 0.1, d);
  }

  boolean outOfBounds() {
    float threshold = node != null ? node.size * node.glowScale/2 : 16;
    return (start.x < -threshold - off.x || start.x > width + threshold - off.x || start.y < -threshold - off.y ||
      pos.y > height + threshold - off.y) && (pos.x < -threshold - off.x || pos.x > width + threshold - off.x || pos.y < -threshold - off.y ||
      pos.y > height + threshold - off.y);
  }

  void split(ArrayList<Tracer> tracersToAdd) {
    if (isSplit) {
      return;
    }
    state = STATE_WAITING;
    boolean done = splits == maxSplits;
    isSplit = true;
    float d = vel.heading();
    float a1 = d - QUARTER_PI/2;
    float a2 = a1 + QUARTER_PI;
    vel.set(0, 0);
    node = new Node(pos.x, pos.y, nodeSize, glowScale, glowOpacity, 255, 0.4, done);
    if (done) {
     return;
    };
    for (int i = 0; i<tracersPerSplit; i++) {
      float f = (float)i/(tracersPerSplit - 1);
      float a = lerp(a1, a2, f);
      tracersToAdd.add(new Tracer(pos.x, pos.y, a, random(minSpeed, maxSpeed), random(minDuration, maxDuration), splits + 1));
    }
  }

  void update() {
    if (node != null) {
      node.update();
    }
    if (state == STATE_BLOWING) {
      if (delay > 0) {
        delay--;
      } else {
        vel.add(wind.x/60, wind.y/60);
        off.add(vel);
      }
    } else if (time >= 1) {
      alive = false;
    } else {
      time += 1 / 60f / duration;
      pos.add(vel.x / 60, vel.y / 60);
    }
  }
  void draw() {
    stroke(tracerColour);
    line(start.x + off.x, start.y + off.y, pos.x + off.x, pos.y + off.y);
    if (node != null) {
      node.draw(off);
    }
  }
}

interface NodeRenderer {
  public void render(float x, float y, float w, float h);
}

class Node {
  
  private final NodeRenderer diamond = new NodeRenderer() {
      public void render(float x, float y, float w, float h) {
      quad(
        x - w / 2, y, 
        x, y - h / 2, 
        x + w / 2, y, 
        x, y + h / 2
        );
    }
  };

  private final NodeRenderer circle = new NodeRenderer() {
      public void render(float x, float y, float w, float h) {
      ellipse(x, y, w, h);
    }
  };

  float time = 0;

  float x, y;
  float size;
  float glowScale;
  float glowOpacity;
  float maxGlowOpacity;
  float flashDuration;
  boolean end;

  public Node(float x, float y, float size, float glowScale, float glowOpacity, float maxGlowOpacity, float flashDuration, boolean end) {
    this.x = x;
    this.y = y;
    this.size = size;
    this.glowScale = glowScale;
    this.maxGlowOpacity = maxGlowOpacity;
    this.glowOpacity = glowOpacity;
    this.flashDuration = flashDuration;
    this.end = end;
  }

  void update() {
    if (time < 1) {
      time += 1 / 60f / flashDuration;
    } else if (time > 1) {
      time = 1;
    }
  }
  void draw(PVector off) {
    if (size == 0) {
      return;
    }

    noStroke();

    NodeRenderer n = end ? circle : diamond;

    if (glowScale != 0) {
      float glowSize = lerp(size, size * glowScale, overshootInterpolator(time, 3));
      float opacity = lerp(maxGlowOpacity, glowOpacity, accelerateInterpolator(time, 1));
      fill(tracerColour, opacity);
      n.render(x + off.x, y + off.y, glowSize, glowSize);
    }

    float adjSize = (1 - pow(1 - time, 4)) * size;
    fill(tracerColour, 255);
    n.render(x + off.x, y + off.y, adjSize, adjSize);
  }
}