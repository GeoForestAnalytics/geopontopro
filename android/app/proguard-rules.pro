# Impede que o Flutter apague ou renomeie suas classes de dados
-keep class com.google.firebase.** { *; }
-keep class com.example.geoponto.models.** { *; }
-keepattributes Signature,Exceptions,InnerClasses