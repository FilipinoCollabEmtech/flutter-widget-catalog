Based on the SeeRuta-related documents, you need to build an **offline geospatial mobile application** for **Cebu City jeepney route discovery and real-time jeepney-code recognition**. The features below are drawn mainly from the Research Plan, SOP, Research Gap, and Data Analysis files.

## Core features to build

1. **Offline geospatial map**
   - Cebu City jeepney routes, stops, destinations, and landmarks.
   - Must work without internet connection.
   - Display routes and destinations on a digital map.

2. **Local route database**
   - Store jeepney route codes, route paths, stops, destinations, and related transportation data locally on the device.
   - Must be searchable and matchable even when offline.

3. **Route discovery and search**
   - Allow users to search for jeepney routes.
   - Identify possible routes based on origin/destination or route code.
   - Show route information, stops, and destination details.

4. **Real-time jeepney-code recognition via OCR**
   - Use the phone camera to capture a jeepney’s route code/signboard.
   - Perform **on-device OCR** to recognize the code in real time.
   - No internet needed for recognition.

5. **Code-to-route matching**
   - Automatically match the recognized jeepney code to the locally stored route database.
   - Retrieve the corresponding route, destination, and geospatial information.

6. **Geospatial route display after recognition**
   - After matching a code, immediately show the route and destination on the offline map.
   - Connect “seeing the jeepney code” to usable digital route information.

7. **Text-to-Speech / voice assistance**
   - Read route, destination, and fare information aloud.
   - Important for accessibility, especially for PWDs and visually impaired users.
   - May include hands-free OCR/TTS features if that is part of your final SOP.

8. **Multilingual voice support**
   - Based on the latest Statement of the Problem file, include multilingual voice assistance.
   - Provide route and destination information in the user’s preferred language.

9. **Fare calculation / fare information**
   - If following the latest SOP file: compute or display estimated jeepney fare.
   - Compare with official jeepney fare rates.
   - Provide fare information before and during the commute.

10. **Accessibility features**
    - Designed for PWDs, tourists, students, and regular commuters.
    - Clear information, logical navigation, readable text, and voice output.
    - Alternative ways to access information aside from purely visual reading.

## Performance and quality features

11. **Reliability**
    - Stable offline performance.
    - No crashes or unexpected interruptions during route search, OCR, or map display.

12. **Fast response time**
    - Quick loading of route information.
    - Quick route searching.
    - Quick OCR recognition and code-to-route matching.

13. **Usability**
    - Effective, efficient, learnable, and error-tolerant.
    - Users should complete tasks like finding a route or recognizing a code without unnecessary difficulty.

14. **Information quality**
    - Accurate, localized, and understandable route, destination, and fare information.

15. **System quality and user satisfaction**
    - Perceived usefulness, ease of use, and overall satisfaction.
    - Reliable system behavior and clear information presentation.

## Research/evaluation features to include

16. **Accuracy testing support**
    - Log correct vs. incorrect OCR results.
    - Compute recognition accuracy and route-matching accuracy.

17. **Response-time testing support**
    - Measure time from image capture to OCR result.
    - Measure time from code recognition to route display.
    - Measure loading and searching times.

18. **Usability testing support**
    - Collect data on effectiveness, efficiency, learnability, errors, and task completion.
    - Collect user perceptions of information quality, system quality, usefulness, and ease of use.

19. **Offline vs. online comparison**
    - If required by your SOP, support comparison between offline and online route information performance.

## Important note

Some files in your upload are **not related to SeeRuta**—for example, the medicine dispenser group, the biosorbent research paper, and the science fair forms for other projects. Do not include features like barcode medicine scanning, pill dispensing, alarms for medication, or biosorbents. Those belong to different studies.

So, for SeeRuta, focus on: **offline map + local route database + route search + on-device OCR + code matching + geospatial display + TTS/voice + accessibility + fare info + performance/usability evaluation.**
