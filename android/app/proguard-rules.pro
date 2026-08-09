-keep class vn.kod.vkmusic.** { *; }
-keep class ** implements vn.kod.vkmusic.VkMusicLib$Callback { *; }
-keepclassmembers class * implements vn.kod.vkmusic.VkMusicLib$Callback {
    public void onSuccess(java.lang.String);
    public void onError(java.lang.String);
}
