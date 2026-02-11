package com.foodshare.ui.design.components.celebration

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import com.foodshare.ui.design.tokens.LiquidGlassColors
import androidx.compose.runtime.withFrameMillis
import kotlinx.coroutines.isActive
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/**
 * Data class representing a single confetti particle
 */
private data class ConfettiParticle(
    var x: Float,
    var y: Float,
    var velocityX: Float,
    var velocityY: Float,
    var rotation: Float,
    var rotationSpeed: Float,
    val color: Color,
    val size: Float
)

/**
 * Canvas-based confetti particle system with gravity and drift
 *
 * @param isPlaying Whether the confetti animation is playing
 * @param modifier Optional modifier for the canvas
 */
@Composable
fun ConfettiView(
    isPlaying: Boolean,
    modifier: Modifier = Modifier
) {
    val particles = remember { mutableStateListOf<ConfettiParticle>() }
    val colors = remember {
        listOf(
            LiquidGlassColors.brandPink,
            LiquidGlassColors.brandTeal,
            LiquidGlassColors.brandOrange,
            LiquidGlassColors.brandGreen,
            LiquidGlassColors.brandBlue
        )
    }

    LaunchedEffect(isPlaying) {
        if (isPlaying) {
            // Initialize particles
            particles.clear()
            repeat(50) {
                particles.add(createRandomParticle(colors))
            }

            // Animation loop
            while (isActive && isPlaying) {
                withFrameMillis { deltaTime ->
                    particles.forEachIndexed { index, particle ->
                        // Apply gravity
                        particle.velocityY += 0.5f

                        // Apply horizontal drift with sine wave
                        particle.velocityX += sin(particle.y / 100f) * 0.1f

                        // Update position
                        particle.x += particle.velocityX
                        particle.y += particle.velocityY

                        // Update rotation
                        particle.rotation += particle.rotationSpeed

                        // Reset particle if it falls off screen
                        if (particle.y > 2000f) {
                            particles[index] = createRandomParticle(colors)
                        }
                    }
                }
            }
        } else {
            particles.clear()
        }
    }

    Canvas(modifier = modifier.fillMaxSize()) {
        particles.forEach { particle ->
            rotate(degrees = particle.rotation, pivot = Offset(particle.x, particle.y)) {
                drawRect(
                    color = particle.color,
                    topLeft = Offset(particle.x - particle.size / 2, particle.y - particle.size / 2),
                    size = androidx.compose.ui.geometry.Size(particle.size, particle.size)
                )
            }
        }
    }
}

/**
 * Creates a random confetti particle with random properties
 */
private fun createRandomParticle(colors: List<Color>): ConfettiParticle {
    return ConfettiParticle(
        x = Random.nextFloat() * 1000f,
        y = Random.nextFloat() * -500f, // Start above screen
        velocityX = Random.nextFloat() * 2f - 1f, // Random horizontal velocity
        velocityY = Random.nextFloat() * 2f + 1f, // Downward velocity
        rotation = Random.nextFloat() * 360f,
        rotationSpeed = Random.nextFloat() * 10f - 5f,
        color = colors.random(),
        size = Random.nextFloat() * 8f + 4f // Size between 4-12
    )
}
