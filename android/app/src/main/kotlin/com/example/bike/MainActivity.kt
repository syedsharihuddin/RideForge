package com.example.bike

import android.graphics.Bitmap
import android.graphics.Color
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.Style
import org.maplibre.android.snapshotter.MapSnapshotter
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.PropertyFactory.circleColor
import org.maplibre.android.style.layers.PropertyFactory.circleRadius
import org.maplibre.android.style.layers.PropertyFactory.circleStrokeColor
import org.maplibre.android.style.layers.PropertyFactory.circleStrokeWidth
import org.maplibre.android.style.layers.PropertyFactory.lineColor
import org.maplibre.android.style.layers.PropertyFactory.lineWidth
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.LineString
import org.maplibre.geojson.Point
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.bike/ride_share_map_snapshot",
        ).setMethodCallHandler { call, result ->
            if (call.method != "capture") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                val args = call.arguments as Map<*, *>
                val width = (args["width"] as Number).toInt()
                val height = (args["height"] as Number).toInt()
                val styleUrl = args["styleUrl"] as String
                val rawRoute = args["routePoints"] as List<*>
                val route = rawRoute.map { rawPoint ->
                    val coordinates = rawPoint as List<*>
                    Point.fromLngLat(
                        (coordinates[0] as Number).toDouble(),
                        (coordinates[1] as Number).toDouble(),
                    )
                }
                if (route.isEmpty()) {
                    result.error("snapshot_failed", "Ride has no GPS points.", null)
                    return@setMethodCallHandler
                }

                val routeBounds = LatLngBounds.Builder().apply {
                    route.forEach { point ->
                        include(LatLng(point.latitude(), point.longitude()))
                    }
                }.build()
                val routeSourceId = "rideforge-share-route"
                val startSourceId = "rideforge-share-start"
                val finishSourceId = "rideforge-share-finish"
                val styleBuilder = Style.Builder()
                    .fromUri(styleUrl)
                    .withSources(
                        GeoJsonSource(routeSourceId, LineString.fromLngLats(route)),
                        GeoJsonSource(startSourceId, route.first()),
                        GeoJsonSource(finishSourceId, route.last()),
                    )
                    .withLayer(
                        LineLayer("rideforge-share-route-layer", routeSourceId)
                            .withProperties(
                                lineColor(Color.rgb(214, 160, 106)),
                                lineWidth(5f),
                            ),
                    )
                    .withLayer(
                        CircleLayer("rideforge-share-start-layer", startSourceId)
                            .withProperties(
                                circleRadius(8f),
                                circleColor(Color.rgb(70, 185, 120)),
                                circleStrokeColor(Color.WHITE),
                                circleStrokeWidth(2f),
                            ),
                    )
                    .withLayer(
                        CircleLayer("rideforge-share-finish-layer", finishSourceId)
                            .withProperties(
                                circleRadius(8f),
                                circleColor(Color.rgb(224, 93, 93)),
                                circleStrokeColor(Color.WHITE),
                                circleStrokeWidth(2f),
                            ),
                    )
                val options = MapSnapshotter.Options(width, height)
                    .withStyleBuilder(styleBuilder)
                    .withAttribution(false)
                    .withLogo(false)
                if (route.size == 1) {
                    val point = route.first()
                    options.withCameraPosition(
                        CameraPosition.Builder()
                            .target(LatLng(point.latitude(), point.longitude()))
                            .zoom(16.0)
                            .build(),
                    )
                } else {
                    options
                        .withRegion(routeBounds)
                        // Keep approximately 12% breathing room on each edge.
                        .withPadding(width / 8, height / 8, width / 8, height / 8)
                }
                val snapshotter = MapSnapshotter(applicationContext, options)
                snapshotter.start({ snapshot ->
                    val output = ByteArrayOutputStream()
                    snapshot.bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                    result.success(output.toByteArray())
                    snapshot.bitmap.recycle()
                }, { error ->
                    Log.e("RideForge", "Share map snapshot failed: $error")
                    result.error("snapshot_failed", error, null)
                })
            } catch (error: Exception) {
                Log.e("RideForge", "Share map snapshot setup failed", error)
                result.error("snapshot_failed", error.message, null)
            }
        }
    }
}
