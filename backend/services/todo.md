# step 0

# step 1

We already implemented in the app to load tons of all workout history, biometrics, basically all health data we can load from apple health kit.
This is a stranenous step, we need to:

- look at all data type by type in the app and refine our memory if necessary, mostly aronud workout, biometric etc. There could be data we missed to add as fields etc.
- then add an endpoint to create a user, just return a user id
- then add an endpoint to allow the app to report user data from appple health kit, it could be quite broad, what the endpoint should do is to:
  - load the corresponding memory file of user, if empty create new
  - fill the data corretly
  - save the file to disk on server for now
    might be helpful to look through the frontend iphone app code to see what kind of data we get from apple health kit
