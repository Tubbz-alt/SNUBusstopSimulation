// The Nature of Code
// Daniel Shiffman
// http://natureofcode.com

// One vehicle "arrives"
// See: http://www.red3d.com/cwr/

ArrayList<Person> ps;
ArrayList<Attractor> stations;
ArrayList<Env> envs;
Env selectedEnv;

void setup() {
  size(800, 500);
  ps = new ArrayList<Person>();
  stations = new ArrayList<Attractor>();
  envs = new ArrayList<Env>();
  
  Env normal = new Env(3);
  normal.setRatio(new float[]{0.4, 0.4, 0.2});
  normal.setStationDir(new float[][]{{0,1}, {0,1}, {0,1}});
  normal.setGuideLineDist(new float[]{5, 5, 5});
  normal.setLineDistortion(new float[]{0, 0, 0});
  normal.setStrictness(new float[]{4, 4, 4});
  
  Env shuffled131115 = normal.copy();
  shuffled131115.shuffle(new int[]{1, 0, 2});
  shuffled131115.setStationDir(new float[][]{{0,1}, {-0.5,1}, {-1,1}});
  shuffled131115.setGuideLineDist(new float[]{15, 10, 5});
  
  Env remove5515 = new Env(2);
  remove5515.setRatio(new float[]{0.3, 0.2});
  remove5515.setStationDir(new float[][]{{-0.5,1}, {-1,1}});
  remove5515.setGuideLineDist(new float[]{15, 10});
  remove5515.setLineDistortion(new float[]{0, 0});
  remove5515.setStrictness(new float[]{10, 5, 3});
  
  
  envs.add(normal);
  envs.add(shuffled131115);
  envs.add(remove5515);
  
  int selectedEnvIdx = 0;
  selectedEnv = envs.get(selectedEnvIdx);
  
  for(int i=0; i<selectedEnv.stationCnt; i++){
    Attractor s = new Attractor(50+i*50, height-30);
    s.direction = selectedEnv.stationDir[i];
    s.lineDistortion = selectedEnv.lineDistortion[i];
    s.guideLineDist = selectedEnv.guideLineDist[i];
    s.col = selectedEnv.colors[i];
    s.strictness = selectedEnv.strictness[i];
    s.certified = true;
    s.isArriving = true;
    
    stations.add(s);
  }
  
  for(int i=0; i<25; i++){
    float r = random(1);
    float rangeStart = 0;
    for(int j=0; j<selectedEnv.personRatio.length; j++){
      if(rangeStart<=r && r<rangeStart+selectedEnv.personRatio[j]){
        ps.add(new Person(random(width*4/5, width), random(height/2, height), j, stations, i));
      }
      rangeStart+=selectedEnv.personRatio[j];
    }
    rangeStart = 0;
  }
  
  
}

void draw() {
  background(255);
  PVector mouse = new PVector(mouseX, mouseY);

  // Draw an ellipse at the mouse position
  fill(200);
  noStroke();
  //ellipse(mouse.x, mouse.y, 48, 48);
  for(Attractor s: stations){
    s.display();
  }


  // Call the appropriate steering behaviors for our agents
  
  for(Person p: ps){
    p.direction = p.velocity.copy().normalize();
  }
  for(Person p: ps){
    p.estimate(ps);                       // get estimate path position ahead
  }
  for(Person p: ps){
    p.validateForward();                  // validate forward Person is on the way of estimate path
  }
  for(Person p: ps){
    p.findLastOfLineAndFollow(ps);          // find person(or station) who is in the last of line(certified or arrived). If found, set forward as him.
  }
  for(Person p: ps){
    p.applyBehaviors(ps);
    p.run();
  }
}

void mousePressed() {
  for(Person p: ps){
    if(abs(p.position.x - mouseX)<10 && abs(p.position.y-mouseY)<10){
      p.debug = !p.debug;
    }
  } 
  for(int i=0; i<25; i++){
    float r = random(1);
    float rangeStart = 0;
    for(int j=0; j<selectedEnv.personRatio.length; j++){
      if(rangeStart<=r && r<rangeStart+selectedEnv.personRatio[j]){
        ps.add(new Person(random(width*4/5, width), random(height/2, height), j, stations, i));
      }
      rangeStart+=selectedEnv.personRatio[j];
    }
    rangeStart = 0;
  }
}

void keyPressed() {
  if (key == '1') {
    for(Person p: ps){
      if(p.fIdx != 0){
        p.seen = false;
      }else{
        p.seen = true;
      }
    } 
  }
  if (key == '2') {
    for(Person p: ps){
      if(p.fIdx != 1){
        p.seen = false;
      }else{
        p.seen = true;
      }
    } 
  }
  if (key == '3') {
    for(Person p: ps){
      if(p.fIdx != 2){
        p.seen = false;
      }else{
        p.seen = true;
      }
    } 
  }
  if (key == '0') {
    for(Person p: ps){
        p.seen = true;
      
    } 
  }
}