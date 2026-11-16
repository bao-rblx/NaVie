# NaVie — Presentation Script (B1 English)

**Total time: 15 minutes.** This script is written in simple English (B1 level).
Short sentences. Common words. Easy to say out loud.

Read it once out loud with a timer before the presentation.

---

## Who speaks when

| Slide | Topic | Speaker | Time |
|---|---|---|---|
| 1 | Title | Bao | 0:30 |
| 2 | The app | Duc | 0:50 |
| 3 | Search | Quang Minh | 0:45 |
| 4 | Four vehicles | Bao | 0:45 |
| 5 | Directions | Duc | 0:45 |
| 6 | Driver mode | Duc | 0:50 |
| 7 | Phone | Duc | 0:35 |
| 8 | Algorithm lab | Bao | 1:00 |
| 9 | Explored nodes | Bao | 0:50 |
| 10 | 42 trips | Minh Nguyen | 1:00 |
| 11 | Route quality | Minh Nguyen | 0:50 |
| 12 | Our setting | Bao | 0:40 |
| 13 | What is missing | Minh Nguyen | 0:50 |
| 14 | Conclusions | Bao | 0:45 |

**Total speaking time: about 11 minutes 45 seconds.**
This leaves about 3 minutes for the live demo and small pauses.

---

## Slide 1 — Title

**Bao:**

> Good morning everyone. We are Group 02.
>
> Our project is called NaVie. It is a route planner for Vietnam.
>
> You type two places. The app finds the best way to go — by motorbike, by car, by taxi, or on foot.
>
> Today we will show you the app first. Then we will show you how it works inside.
>
> Let's start.

---

## Slide 2 — The app

**Duc:**

> This is our app. It is running now.
>
> On the left, you can see the search box. I type my start point here, and my destination here.
>
> Then I press "Find route". And the app shows me the road on the map.
>
> The green line is my route. Point A is where I start. Point B is where I finish.
>
> It also shows the distance and the time. This trip is five kilometres and takes about nine minutes.
>
> We use real map data from OpenStreetMap. It is free, and we do not need any API key.

---

## Slide 3 — Search

**Quang Minh:**

> Before the app can find a route, it needs to know where you want to go.
>
> So we built our own search for place names.
>
> You can type with Vietnamese accents. You can also type without accents. Both work.
>
> For example, "Chợ Bến Thành" and "ben thanh" find the same market.
>
> The search is fast. It answers in less than one second.
>
> And it works offline. We do not need internet for this part.

---

## Slide 4 — Four vehicles

**Bao:**

> The same trip can be different for each vehicle.
>
> A motorbike cannot use the motorway. That is against the law in Vietnam.
>
> A car must follow one-way streets. But a person on foot can walk the wrong way down a one-way street.
>
> A truck has more rules. It must be light enough and short enough for the road.
>
> So we use one map. But we filter the roads for each vehicle.
>
> This means the app can give a correct route for each one.

---

## Slide 5 — Directions

**Duc:**

> A line on a map is not enough. The driver needs to know where to turn.
>
> So the app gives turn-by-turn directions.
>
> Look at the list on the left. It says things like "Rẽ phải vào Đồng Khởi". That means "turn right onto Đồng Khởi street".
>
> We do not write these by hand. The app makes them automatically.
>
> It looks at the angle of every corner. If the road turns right, it says turn right. Then it finds the street name from the map data.
>
> On this route, it made 22 instructions.

---

## Slide 6 — Driver mode

**Duc:**

> We also made a driver mode. This is for when you are actually driving.
>
> The big green box at the top tells you the next turn. Right now it says turn right in 440 metres.
>
> The map turns with you. So the road in front of you is always at the top of the screen.
>
> At the bottom, you can see the time left, the distance left, and the arrival time.
>
> One important thing: this is a simulation. It says "Mô phỏng" — that means simulation in Vietnamese.
>
> We label it clearly. We do not want anyone to think this is real GPS.

---

## Slide 7 — Phone

**Duc:**

> The same app also works on a phone. This is the phone layout.
>
> On a small screen, we put the map on the top and the buttons on the bottom. So you can use it with one hand.
>
> And this is why the algorithms matter.
>
> A phone must answer very fast. If the search is slow, the user waits. Or the route is bad.
>
> So the next slides compare our search algorithms. On this same app. On a real city.

---

## Slide 8 — Algorithm lab

**Bao:**

> We wrote six search algorithms ourselves. We did not use a library.
>
> This screen lets us compare two algorithms on the same trip.
>
> On the left I choose A*. On the right I choose Dijkstra. Same start, same destination.
>
> Look at the numbers.
>
> A* checked 7,352 junctions. It took 9.8 milliseconds.
>
> Dijkstra checked 30,041 junctions. It took 41 milliseconds.
>
> A* did four times less work. But the route is the same. Both are 5.1 kilometres.
>
> This is the main result of our project.

---

## Slide 9 — Explored nodes

**Bao:**

> This is the same thing, but you can see it.
>
> Every blue dot is a road junction that the algorithm had to check.
>
> Look at the shape. It is a big cloud around the start point.
>
> Dijkstra does not know where the destination is. So it searches in every direction. It fills the whole city.
>
> A* is smarter. It knows the direction of the destination. So it searches mostly forward, along the green line.
>
> That is why A* is faster. It is not magic. It just knows which way to go.

---

## Slide 10 — 42 trips

**Minh Nguyen:**

> One trip is not enough to prove anything. So we tested more.
>
> We took 42 random trips in Ho Chi Minh City. Same map. Same vehicle. Same start and destination for every algorithm.
>
> This chart shows the average number of junctions each algorithm checked.
>
> Dijkstra is at the top: 89,337 junctions. That is 65 percent of the whole city map. For one trip.
>
> A* is half: 44,632.
>
> Our weighted version is 15,760.
>
> Greedy is very small: 569. But be careful — look at the red box. Greedy gives a bad route on 41 of 42 trips.
>
> So being fast is not enough.

---

## Slide 11 — Route quality

**Minh Nguyen:**

> This slide shows route quality.
>
> The line at 1.0 is the perfect route. The best possible route.
>
> A*, Dijkstra, and the bidirectional versions are all exactly on the line. They always find the best route.
>
> Greedy is far away. On average, its route is twice as long as the best route. In the worst case, it is three times longer.
>
> Our weighted version is very close to the line. Only 0.2 percent worse on average.
>
> So we have a choice: save work, or get a better route. Weighted A* gives us both.

---

## Slide 12 — Our setting

**Bao:**

> This chart shows the trade-off. The blue line is the work. The red line is the route quality.
>
> When we increase the weight, the work goes down a lot.
>
> At 1.5, the work is three times less. But the red line is still at the bottom. The route is still the best.
>
> At 2, the route gets 3 percent worse. At 3, it gets 7 percent worse.
>
> So we choose 1.5. It is a good balance. The app uses this by default.

---

## Slide 13 — What is missing

**Minh Nguyen:**

> Now we want to be honest with you. Some parts are not finished.
>
> First, live traffic. We designed a traffic model, but we did not finish it. So 8 in the morning and 3 in the morning give the same time estimate. That is not realistic.
>
> Second, prices. We do not have real price data. So the app says "price not verified" instead of making up a number.
>
> Third, multi-stop delivery. We planned it, but we did not build it.
>
> Fourth, live incidents. The app can reroute if you leave the road. But you cannot report a flooded street yet.
>
> And fifth, one algorithm — IDA* — is too slow. It cannot finish a real city trip. We kept it, and we report it honestly.
>
> We think it is better to show what works and say what does not work.

---

## Slide 14 — Conclusions

**Bao:**

> To finish, here is what we built.
>
> One: a working route planner. You can search a place, choose a vehicle, and see the route.
>
> Two: a driver mode with turn instructions in Vietnamese.
>
> Three: six search algorithms that we wrote ourselves. A* is four times faster than Dijkstra on this map, and we can show it.
>
> Four: an honest comparison. We show the good results, and we show the bad ones.
>
> Thank you for listening. We are happy to answer your questions.

**All:** stay on this slide during questions.

---

# Live demo (if you have time)

Do this **only** if you have 2–3 minutes left. Otherwise skip it.

1. Open the app on the laptop.
2. Type **Chợ Bến Thành** in the first box.
3. Type **Landmark 81** in the second box.
4. Press **Find route**.
5. Wait for the route to appear. Say: *"This is a real route from our own algorithm."*
6. Click **Route lab** on the left.
7. Choose **A*** and **Dijkstra**. Press **Compare**.
8. Say: *"Same trip. A* checked 7,352 junctions. Dijkstra checked 30,041."*
9. Click **Show explored nodes**.
10. Say: *"You can see it. Dijkstra fills the whole city. A* goes straight to the goal."*

**If the internet is slow or the app fails:** do not wait. Say: *"The network is slow, so I will show you the screenshot instead."* Then go back to the slides.

---

# Questions you may get (and simple answers)

**"Why did you not use Google Maps?"**
> We wanted to write the algorithms ourselves. That is the main point of this project. Google Maps is a black box. We cannot see inside.

**"Is your app accurate?"**
> The roads and distances are accurate, because they come from OpenStreetMap. The time is an estimate. We do not have live traffic yet, so it is free-flow time.

**"What is A*?"**
> It is a search algorithm. It works like Dijkstra, but it also uses a guess about the distance to the destination. That guess helps it search in the right direction.

**"Why is A* faster?"**
> Because it knows where the destination is. Dijkstra searches in all directions. A* searches mostly forward. So it checks fewer roads.

**"What happens if the road is closed?"**
> Right now the app can reroute if you leave the route. But you cannot report a closed road yet. That is future work.

**"How many lines of code?"**
> About 1,000 lines in the backend, plus the web app and the Flutter app.

**"Did you use AI to write the code?"**
> Yes, we used AI tools to help write the code. We recorded every use in a log file. We tested all the code ourselves. The report explains this.

**"What was the hardest part?"**
> Building the road map. We had to download OpenStreetMap data, clean it, and put it into a format that is fast to search.

---

# How to say difficult words

| Word | How to say it |
|---|---|
| Dijkstra | **DIKE-stra** |
| A* | **"A star"** |
| NaVie | **NAH-vee** |
| Bến Thành | **ben TAN** |
| Landmark 81 | **LAND-mark eighty-one** |
| Đồng Khởi | **dom KHOY** |
| Mô phỏng | **moh FONG** |
| heuristic | **hyoo-RIS-tik** |
| algorithm | **AL-go-rith-em** |

---

# Tips for B1 speakers

1. **Speak slowly.** Slower is better. If you speak fast, people cannot follow.
2. **Pause after each slide.** Take a breath. Let people look at the picture.
3. **Point at the screen.** When you say a number, point to it. Say: *"Look here — 7,352."*
4. **Do not read the slide word by word.** The slide is for the audience. Your voice is the explanation.
5. **If you forget a word,** say it in a simpler way. For example: "junction" → "road corner".
6. **If you make a mistake,** just continue. Do not say sorry many times.
7. **Practise out loud 3 times** with a timer. Not in your head — out loud.

---

# Final checklist

- [ ] Practise the whole script out loud 3 times with a timer
- [ ] Each person knows their slides and their time
- [ ] Backend is running on port 8000
- [ ] Web app is open on port 8080
- [ ] The demo route is tested once before you start
- [ ] A backup screen recording is ready (in case the network fails)
- [ ] Laptop is charged and connected to the projector
- [ ] Everyone knows: **stay on the conclusions slide during questions**
