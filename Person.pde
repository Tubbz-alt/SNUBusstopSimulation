
class Person extends Attractor {
  PVector acceleration;
  float r;
  float maxforce;    // Maximum steering force
  float maxspeed;    // Maximum speed
  float lineDistortion;
  boolean[] found;
  boolean debug;
  boolean seen;
  boolean guessing;
  ArrayList<Attractor> stations;
  int fIdx;
  int tick;
  int log;
  Attractor follow; // object that person follow. Initialized with bus station position
  Attractor estimateTarget;


  boolean[] stressEn;
  int[] stressCnt;
  boolean seeStress;



  Person(float x, float y, int _fIdx, ArrayList<Attractor> _stations, int _n) {
    super(x, y, _n);
    tick = 0;
    float defaultStationInterval = 400;
    float pxResolution = 13/defaultStationInterval;
    /**
     * Length from subway to left ahead of 5511 station is 67.375m
     * Length of left ahead of 5515 station is 1.625m
     * The screen's expression range is 52m
     * Duration time of person who goes to 5511 station is 50sec
     * Thus, v = (1.1/0.0325)px/sec = 33.84
     * We'll use velocity multiplied by systempSpeed magnitude(v*systemSpeed). 
     **/
    maxspeed = (33.84*systemSpeed/60.0)+random(-0.5, 0.5);
    maxforce = map(systemSpeed, 1, 12, 0.1, 1.2);
    stations = _stations;
    fIdx = _fIdx;
    follow = stations.get(fIdx);
    col = follow.col;
    if (fIdx == 3) follow = new Attractor(-100, random(0, height*4/5)); 
    r = 3;
    acceleration = new PVector(0, 0);
    velocity = new PVector(0, 0);
    certified = false;
    found = new boolean[_stations.size()];
    //found[found.length-2] = true;
    lineDistortion = random(follow.lineDistortion, follow.lineDistortion*2);
    debug = false;
    seen = true;
    guessing = false;


    stressEn = new boolean[] {true, true, true, true};
    stressCnt = new int[]{0, 0, 0, 0};
    stress = 0;
    seeStress = false;
    log = 0;
  }

  public void run() {
    tick+=1;
    tick%=100;
    update();
    display();
  }

  void update() {
    if (!certified || (everCertified && forward!=null && (PVector.dist(position, forward.position) > getIntervalSize()*3))) {
      // Update velocity
      velocity.add(acceleration);
      // Limit speed
      velocity.limit(maxspeed);
      //velocity.x = velocity.x>0 ? velocity.x*0.1 : velocity.x;
      position.add(velocity);
      // Reset accelerationelertion to 0 each cycle
      acceleration.mult(0);
    } else {
      if (forward!=null && forward.equals(stations.get(fIdx))) {
        stations.get(fIdx).isReady = true;
      }
    }


    setStress();
    setStressEn();
  }

  void applyForce(PVector force) {
    // We could add mass here if we want A = F / M
    acceleration.add(force);
  }

  void applyBehaviors(ArrayList<Person> ps) {
    if (!certified || (everCertified && forward!=null && (PVector.dist(position, forward.position) > getIntervalSize()*3))) {
      PVector separateForce = separate(ps);
      PVector arriveForce = arrive();
      separateForce.mult(2);
      arriveForce.mult(1);
      applyForce(separateForce);
      applyForce(arriveForce);
    }
    getStress(ps);
  }

  void validateForward() {
    //if (forward!=null && !found[fIdx]) {
    if (forward!=null) {
      boolean invalid = false;
      PVector estimatePath = PVector.sub(estimateTarget.position, position).normalize();
      PVector forwardDirection = PVector.sub(forward.position, position).normalize();

      float angle = PVector.angleBetween(estimatePath, forwardDirection);
      if (everCertified) {
        int aheadCnt = 0;
        Attractor pointer = this;
        while (pointer.forward!=null) {
          aheadCnt++;
          pointer = pointer.forward;
        }
        if (aheadCnt<20 && !pointer.equals(stations.get(fIdx))) {
          invalid = true;
        }
        if (stations.get(fIdx).position.x > position.x && !pointer.equals(stations.get(fIdx))) {
          invalid = true;
        }
      } else {
        if (angle>15*PI/180) {
          invalid = true;
        }
      }
      if (invalid) {
        if (forward!=null) {
          if (everCertified) {
            forward.backward = backward;
          } else {
            forward.backward = null;
          }
        }
        if (backward!=null) {
          if (everCertified) {
            backward.forward  = forward;
          } else {
            backward.forward  = null;
          }
        }

        forward = null;
        backward = null;
        everCertified = false;
        certified = false;
        isArriving = false;
        maxspeed = (33.84*systemSpeed/60.0)+random(-0.5, 0.5);
        if (stressEn[2]) {
          stressCnt[2]++;
          stressEn[2] = false;
        }
      }
    }
  }


  void findLastOfLineAndFollow(ArrayList<Person> ps) {
    Attractor[] minDistCandidates = new Attractor[stations.size()];
    for (int i=0; i<stations.size(); i++) {
      minDistCandidates[i] = null;
    }
    for (int i=0; i<found.length; i++) {
      if (found[i]) {
        continue;
      } else {
        Attractor station = stations.get(i);
        PVector towardStation = PVector.sub(station.position, position);
        ArrayList<Attractor> candidates = new ArrayList<Attractor>();
        for (Person other : ps) {
          if (other!=this) {
            if (PVector.dist(other.position, station.position) < towardStation.mag()) {
              PVector towardOther = PVector.sub(other.position, position);
              if (towardOther.mag() > towardStation.mag()) {
                continue;
              }
              float theta = PVector.angleBetween(towardStation, towardOther);
              float dist = abs(towardOther.mag()*sin(theta));
              if (dist < getIntervalSize()) {
                candidates.add(other);
              }
            }
          }
        }
        if (candidates.size()>0) {
          found[i] = false;
        } else {
          found[i] = true;
          guessing = false;
          
          if(fIdx+1 < stations.size() && found[fIdx+1]){
            found[fIdx] = true;
            guessing = false;
          }
        }
        if (towardStation.mag() <200) {
          found[i] = true;
        }

        for (int j=candidates.size()-1; j>=0; j--) {
          if (!candidates.get(j).certified && !candidates.get(j).isArriving) {
            candidates.remove(j);
          }
        }
        if (candidates.size()>0) {
          Attractor min = candidates.get(0);
          for (Attractor c : candidates) {
            if (PVector.dist(min.position, position) > PVector.dist(c.position, position)) {
              min = c;
            }
          }      
          minDistCandidates[i] = min;
        }
      }
    }


    if (!found[fIdx]) {
      if (minDistCandidates[fIdx]!=null) {
        Attractor lastCertified = lastAttractorOfLine(minDistCandidates[fIdx]);
        if (lastCertified!=null) {
          Attractor temp = lastCertified;
          boolean isAnotherLine = false;
          float sightDistance = getIntervalSize()*4;
          float periphery = PI/8;
          while (temp.forward!=null) {
            ArrayList<Attractor> similar = new ArrayList<Attractor>();
            for (Person other : ps) {
              if (other!=this) {
                // A vector that points to another boid and that angle
                PVector comparison = PVector.sub(other.position, temp.position);

                // How far is it
                float d = PVector.dist(temp.position, other.position);

                // What is the angle between the other boid and this one's current direction
                float diff = PVector.angleBetween(comparison, velocity);

                // If it's within the periphery and close enough to see it
                if (diff < periphery && d > 0 && d < sightDistance) {
                  similar.add(other);
                }
              }
            }
            if (similar.size()>0) {
              guessing = true;
              break;
              //temp = similar.get((int)random(similar.size()));
            } else {
              temp = temp.forward;
              guessing = false;
            }
          }
          if (!guessing) {
            for (int i=0; i<found.length; i++) {
              if (i!=fIdx && found[i] && stations.get(i).equals(temp)) {
                isAnotherLine = true;
                break;
              }
            }
            if (!isAnotherLine) {
              found[fIdx] = true;
              guessing = false;
              if(fIdx+1 < stations.size() && found[fIdx+1]){
                found[fIdx] = true;
                guessing = false;
              }
              //col = color(255, 0, 255); //purple
              setForward(lastAttractorOfLine(stations.get(fIdx)));
            }
          } else {
            //do nothing.. only guessing.. 
            //affect to estimate function
            ArrayList<Attractor> guessCandidates = new ArrayList<Attractor>();
            for (Person p : ps) {
              PVector comparer = new PVector(-1, 0);
              if (p.certified) {
                Attractor toPush = lastAttractorOfLine(p);
                if (!guessCandidates.contains(toPush)) {
                  guessCandidates.add(toPush);
                }
              }
            }
            for (int i = 1; i < guessCandidates.size(); i++) {          
              Attractor tmpC = guessCandidates.get(i);
              int aux = i - 1;
              while ( (aux >= 0) && ( guessCandidates.get(aux).position.y > tmpC.position.y) ) {
                guessCandidates.set(aux+1, guessCandidates.get(aux));
                aux--;
              }
              guessCandidates.set(aux + 1, tmpC);
            }

            for (int i=guessCandidates.size()-1; i>=0; i--) {
              Attractor gc = guessCandidates.get(i);
              PVector towardGc = PVector.sub(gc.position, position);
              for (Person other : ps) {

                if (other!=this) {
                  if (PVector.dist(other.position, position) < towardGc.mag()) {
                    PVector towardOther = PVector.sub(other.position, position);

                    float theta = PVector.angleBetween(towardGc, towardOther);
                    float dist = abs(towardOther.mag()*sin(theta));
                    if (dist < getIntervalSize()) {
                      guessCandidates.remove(gc);
                      break;
                    }
                  }
                }
              }
            }
            if (guessCandidates.size()>fIdx && PVector.dist(guessCandidates.get(fIdx).position, estimateTarget.position)<400) {
              guessing = false;
              setForward(guessCandidates.get(fIdx));
            }
          }
        }
      }
    } else {
      Attractor lastCertified = lastAttractorOfLine(stations.get(fIdx));
      if (lastCertified!=null) {
        //col = color(0, 255, 255); //cyan
        guessing = false;
        setForward(lastCertified);
        //println("3#");
      } else {
        //println("3");
      }
    }
  }


  void setForward(Attractor attr) {
    Attractor uncertain = attr;
    if (uncertain!=null) {
      //Check distance from estimate path from attr
      //If it exceed some value, skip setting forward process.
      float intervalSize = getIntervalSize();
      Attractor tempTarget;
      tempTarget = attr.copy();
      float distBWpath = PVector.dist(position, tempTarget.position);
      boolean skip = false;

      float maximumDist = 1.5*intervalSize; //critical to bottle neck 11.24, lower than 2 is proper.
      while (true) {
        //float maximumDist = map(iterCnt, 0, 20, 1.5, 50)*intervalSize; //critical to bottle neck 11.24, lower than 2 is proper.
        tempTarget.position = PVector.sub(tempTarget.position, tempTarget.direction.copy().normalize().setMag(3*intervalSize));
        tempTarget.direction = tempTarget.direction.copy().normalize().rotate(tempTarget.lineDistortion);  //set direction
        if (tempTarget.direction.heading()<0) {
          tempTarget.direction = new PVector(-1, 0);
        }

        if (PVector.dist(position, tempTarget.position) < maximumDist) {
          break;
        }
        if (PVector.dist(position, tempTarget.position) - distBWpath > 0) {
          skip = true;
          break;
        } else {
          rect(tempTarget.position.x, tempTarget.position.y, 5, 5);
          distBWpath = PVector.dist(position, tempTarget.position);
        }
      }
      if (!skip) {
        // set forward process.
        boolean inserted = false;
        while (uncertain.backward!=null && !uncertain.backward.equals(this)) {
          float diff = PVector.dist(uncertain.position, uncertain.backward.position) - PVector.dist(uncertain.position, position);
          if (diff>0) {
            if (this.forward!=null) {
              this.forward.backward = null;
              this.forward = null;
            }
            if (this.backward!=null) {
              this.backward.forward = null;
              this.backward = null;
            }
            this.backward = uncertain.backward;
            this.backward.forward = this;
            uncertain.backward = this;
            this.forward = uncertain;
            inserted = true;

            if (stressEn[1]) {
              stressCnt[1]++;
              stressEn[1] = false;
            }

            break;
          } else {
            uncertain = uncertain.backward;
          }
        }
        if (!inserted) {
          uncertain.backward = this;
          forward = uncertain;
        }
      }
    } else {
      if (forward!=null) {
        forward.backward = null;
        forward = null;
      }
      if (backward!=null) {
        backward.forward = null;
        backward = null;
      }

      if (stressEn[1]) {
        stressCnt[1]++;
        stressEn[1] = false;
      }
    }



    //check validation
    for (int i=0; i<stations.size(); i++) {
      Attractor checker = stations.get(i);
      while (checker.backward!=null) {
        if (checker.backward.forward==null || !checker.backward.forward.equals(checker)) {
          //throw link error
          checker.backward = null;
        } else {
          checker = checker.backward;
        }
      }
    }
  }



  boolean certify() {
    boolean certifyOk = false;
    Attractor curr = this;
    while (curr.forward!=null) {
      if (curr.forward.certified) {
        curr = curr.forward;
      } else {
        return certifyOk;
      }
    }
    if (!curr.certified) {
      return certifyOk;
    }
    certified = true;
    everCertified = true;
    certifyOk = true;
    //direction = forward.direction.copy();  //set direction
    if (!forward.equals(stations.get(fIdx))) {
      direction = forward.velocity.copy().normalize().rotate(lineDistortion);  //set direction
      if (direction.heading()<0) {
        direction = new PVector(-1, 0);
      }
      velocity = direction.copy();
      maxspeed = 1.0;
    } else {
      direction = velocity.copy().normalize();
      velocity = velocity.normalize();
      maxspeed = 1.0;
    }
    return certifyOk;
  }


  Attractor lastAttractorOfLine(Attractor start) {
    Attractor curr = start;
    while (curr.backward!=null && !curr.backward.equals(this) && (curr.backward.certified)) {
      curr = curr.backward;
    }
    if (!curr.certified) {
      return null;
    }
    return curr;
  }

  void estimate(ArrayList<Person> ps) {
    float intervalSize = getIntervalSize();
    Attractor tempTarget = new Attractor();
    int cnt = found[fIdx] ? (int)stations.get(fIdx).guideLineDist : (int)stations.get(fIdx).guideLineDist+5;  //11.24
    tempTarget = (!found[fIdx] && guessing) ? stations.get(fIdx).copy() : lastAttractorOfLine(stations.get(fIdx)).copy();
    if (!found[fIdx] && guessing) {
      tempTarget.position.x +=100;
      tempTarget.position.y +=15;
    } else {
      for (int i=0; i<cnt; i++) {
        tempTarget.position = PVector.sub(tempTarget.position, tempTarget.direction.copy().normalize().setMag(intervalSize));
        tempTarget.direction = tempTarget.direction.copy().normalize().rotate(lineDistortion);  //set direction
        if (tempTarget.direction.heading()<0) {
          tempTarget.direction = new PVector(-1, 0);
        }

        if (PVector.dist(position, tempTarget.position) < stations.get(fIdx).strictness*intervalSize) {
          break;
        }
      }
    }


    estimateTarget = tempTarget;


    if (certified) {
      fill(estimateTarget.col);
      rect(estimateTarget.position.x, estimateTarget.position.y, 4, 4);
    } else {
      fill(estimateTarget.col);
      ellipse(estimateTarget.position.x, estimateTarget.position.y, 4, 4);
    }
  }




  // A method that calculates a steering force towards a target
  // STEER = DESIRED MINUS VELOCITY
  PVector arrive() {
    float intervalSize = getIntervalSize();
    Attractor _target;
    PVector targetDir;
    PVector target;
    if (everForward!=null && forward!=null && PVector.dist(everForward.position, forward.position)<3*intervalSize) {
      _target = everForward;
      targetDir = _target.direction.copy();
      target = _target.position.copy();
    } else {
      _target = forward!=null ? forward: estimateTarget;
      targetDir = _target.direction.copy().rotate(lineDistortion);
      if (targetDir.heading()<0) {

        targetDir = new PVector(-10, 1).normalize();

      }
      if (!guessing) {
        target = PVector.sub(_target.position, targetDir.setMag(2*intervalSize));
      } else {
        target = _target.position;
      }
    }




    //PVector target = _target.position;
    float arriveDistance = 4*intervalSize; //40
    //float arriveDistance = map(systemSpeed, 1, 12, 4, 24)*intervalSize; //40
    //arriveDistance = constrain(arriveDistance, intervalSize, stations.get(fIdx).strictness*intervalSize);
    PVector desired = PVector.sub(target, position);  // A vector pointing from the position to the target
    float d = desired.mag();
    // Scale with arbitrary damping within 100 pixels
    if (d < arriveDistance) {
      float m = map(d, 0, arriveDistance, 0, maxspeed);
      isArriving = true;
      if (m<0.25) {  //critical to distortion shape
        if (certify()) {
          return new PVector(0, 0);
        }
      }
      desired.setMag(m);
    } else {
      isArriving = false;
      desired.setMag(maxspeed);
    }
    // Steering = Desired minus Velocity
    PVector steer = PVector.sub(desired, velocity);
    steer.limit(maxforce);  // Limit to maximum steering force
    return steer;
  }


  PVector separate (ArrayList<Person> boids) {
    float distanceFromAttractor = PVector.dist(estimateTarget.position, position);
    float desiredseparation = getIntervalSize()*2;
    float periphery = PI/2;
    PVector avgVel = new PVector(0, 0);
    PVector steer = new PVector(0, 0);
    //if (distanceFromAttractor < getIntervalSize()*4) { 
    //  return steer;
    //}
    int count = 0;
    // For every boid in the system, check if it's too close
    for (Person other : boids) {
      if (other!=this && !other.isArriving && !everCertified) {
        PVector comparison = PVector.sub(other.position, position);

        // How far is it
        float d = PVector.dist(position, other.position);

        // What is the angle between the other boid and this one's current direction
        float diff = PVector.angleBetween(comparison, velocity);
        // If it's within the periphery and close enough to see it
        if (diff < periphery && d > 0 && d < desiredseparation && !other.certified) {
          PVector diff2 = PVector.sub(position, other.position);
          avgVel.add(other.velocity);
          diff2.normalize();
          diff2.div(d);        // Weight by distance
          steer.add(diff2);
          count++;            // Keep track of how many
        }
      }
    }
    // Average -- divide by how many
    if (count > 0) {
      float contourDistance = 150;
      steer.div((float)count);
      avgVel.div((float)count);
      if (contourDistance < distanceFromAttractor && avgVel.mag() < velocity.mag()) {
        float headingBetween = velocity.heading() - avgVel.mag();
        PVector contour;
        if (headingBetween > 0 ) {
          contour = velocity.copy().rotate(PI/6);
        } else {
          contour = velocity.copy().rotate(-PI/6);
        }
        contour.normalize();
        steer.add(contour);
      }
      // Implement Reynolds: Steering = Desired - Velocity
      steer.normalize();
      steer.mult(maxspeed);
      steer.sub(velocity);
      steer.limit(maxforce);
    }
    return steer;
  }


  void display() {
    if (seen) {
      // Draw a triangle rotated in the direction of velocity
      //if(debug){
      if (forward!=null) {
        forward.debugged = true;
      }
      //}
      if (debugged) {
        //col = color(255, 0, 255);
      }


      float theta = velocity.heading() + radians(90);

      if (certified) {
        //col = color(0, 255, 255);
      }
      if (found[fIdx]) {
        //col = color(0, 255, 255);
      }
      fill(col);
      noStroke();
      pushMatrix();
      translate(position.x, position.y);
      rotate(theta);
      beginShape(TRIANGLES);
      vertex(0, -r*2);
      vertex(-r, r*2);
      vertex(r, r*2);
      endShape();
      popMatrix();



      if (debug) {
        int cnt = -1;
        if (forward!=null) {
          Attractor curr = stations.get(fIdx);
          while (curr!=null) {
            if (curr.equals(this)) {
              break;
            }
            cnt++;
            curr = curr.backward;
          }
          if (cnt!=-1) {
            textSize(10);
            text(cnt, position.x, position.y);
          }
        }


        text(name, position.x, position.y+10);
        String s = "";
        Attractor tmp = stations.get(fIdx);

        while (tmp.backward!=null) {
          s+= tmp.backward.name +" ";
          tmp = tmp.backward;
        }
        text(s, 50, 20+10*fIdx);

        if (certified) {
          fill(0);
          text("!!", position.x, position.y-10);
        }
      }

      if (seeStress) {

        float a = r * (1 + 0.08*stress); // *******************adjust constant

        float k = constrain(a, r, 3*r);
        fill(col);
        noStroke();
        pushMatrix();
        translate(position.x, position.y);
        rotate(theta);
        beginShape(TRIANGLES);
        vertex(0, -k*2);
        vertex(-k, k*2);
        vertex(k, k*2);
        endShape();
        popMatrix();
      }
    }
  }

  float getIntervalSize() {
    return (r*3);
  }


  void pedestBehaviors(ArrayList<Person> ps) {
    estimateTarget = follow;
    PVector separateForce = separate(ps);
    PVector arriveForce = arrive();
    separateForce.mult(2);
    arriveForce.mult(1);
    applyForce(separateForce);
    applyForce(arriveForce);
  }

  void removePedest() {
    if (position.x<0) ps.remove(this);
  }

  void setStress() {

    stress = stressCnt[0]*1 + stressCnt[1]*8.3 + stressCnt[2]*8.9 + stressCnt[3]*6.8;// **************adjust constant
  }

  void setStressEn() {
    if (tick == 0) { // ******************* adjust tick
      stressEn[0] = true;
      stressEn[1] = true;
    }
  }

  void getStress(ArrayList<Person> ps) {
    for (Person p : ps) { ////////////////////////stress0
      if (p!=this && !p.isArriving) {
        float d = PVector.dist(position, p.position);
        float desiredseparation = getIntervalSize()*2;
        if (d > 0 && d < desiredseparation && !p.certified) {
          if (stressEn[0]) {
            stressCnt[0]++;
            stressEn[0] = false;
          }
        }
      }
    }

    if (certified && stressEn[3]) { ///////////////////stress3
      for (Person p : ps) {
        float d = PVector.dist(position, p.position);
        float desiredseparation = getIntervalSize()*2;
        if (p != this && d > 0 && d < desiredseparation && p.everCertified == true && p.fIdx != fIdx) {
          stressCnt[3]++;
        }
      }
      stressEn[3] = false;
    }
  }
}



//case 1 : when tracking line is possible : estimate destination of line according to the information of the number of people in front of view
//case 2 : when it is impossible to trackng line : Get streesed and,
//     2-1 : count the number of lines and choose one