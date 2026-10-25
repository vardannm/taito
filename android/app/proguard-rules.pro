# WorkManager is initialized before Flutter by AndroidX Startup. Room creates
# this generated database through reflection, so R8 must retain its constructor.
# Without it, release builds crash with "Failed to create an instance of
# androidx.work.impl.WorkDatabase" before the game can open.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
