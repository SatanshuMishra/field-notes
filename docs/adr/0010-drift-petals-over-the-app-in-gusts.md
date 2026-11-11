# Drift petals over the app in gusts with long rests

Status: accepted

Impeller keeps no raster cache, so every frame a drifting petal asks for re-renders the whole page beneath it, blurs included, and continuous petals held a weak phone's raster thread near 70% all day. Over the app the petals now cross the window in gusts, each followed by a still rest four to five times the gust's length, while onboarding keeps its continuous fall. Lowering the petals' frame rate was rejected because it steps down the motion's smoothness, and caching the page as a picture under the petals was rejected for its engine risk and graphics memory on Windows. The cost is that petals are absent for most of any minute.
