package com.foodshare.features.search.presentation

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.foodshare.domain.model.DietaryPreference
import com.foodshare.domain.model.FilterPreset
import com.foodshare.domain.model.SearchFilters
import com.foodshare.domain.model.SortOption

/**
 * Filter bottom sheet content
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun FilterSheet(
    filters: SearchFilters,
    presets: List<FilterPreset>,
    onFiltersChange: (SearchFilters) -> Unit,
    onApply: () -> Unit,
    onClear: () -> Unit,
    onSavePreset: (String) -> Unit,
    onApplyPreset: (FilterPreset) -> Unit,
    onDeletePreset: (FilterPreset) -> Unit
) {
    var showSaveDialog by remember { mutableStateOf(false) }
    var presetName by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Filters",
                style = MaterialTheme.typography.titleLarge
            )
            TextButton(onClick = onClear) {
                Text("Clear All")
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Saved presets
        if (presets.isNotEmpty()) {
            Text(
                text = "Saved Presets",
                style = MaterialTheme.typography.titleSmall
            )
            Spacer(modifier = Modifier.height(8.dp))
            FlowRow(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                presets.forEach { preset ->
                    FilterChip(
                        selected = false,
                        onClick = { onApplyPreset(preset) },
                        label = { Text(preset.name) },
                        trailingIcon = {
                            IconButton(
                                onClick = { onDeletePreset(preset) },
                                modifier = Modifier.then(Modifier)
                            ) {
                                Icon(
                                    Icons.Default.Delete,
                                    contentDescription = "Delete",
                                    modifier = Modifier.then(Modifier)
                                )
                            }
                        }
                    )
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            HorizontalDivider()
            Spacer(modifier = Modifier.height(16.dp))
        }

        // Distance slider
        Text(
            text = "Distance: ${filters.radiusKm.toInt()} km",
            style = MaterialTheme.typography.titleSmall
        )
        Slider(
            value = filters.radiusKm.toFloat(),
            onValueChange = {
                onFiltersChange(filters.copy(radiusKm = it.toDouble()))
            },
            valueRange = 1f..100f,
            steps = 19
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Sort by
        Text(
            text = "Sort By",
            style = MaterialTheme.typography.titleSmall
        )
        Spacer(modifier = Modifier.height(8.dp))
        FlowRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            SortOption.entries.forEach { option ->
                FilterChip(
                    selected = filters.sortBy == option,
                    onClick = {
                        onFiltersChange(filters.copy(sortBy = option))
                    },
                    label = { Text(option.displayName) }
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Dietary preferences
        Text(
            text = "Dietary Preferences",
            style = MaterialTheme.typography.titleSmall
        )
        Spacer(modifier = Modifier.height(8.dp))
        FlowRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            DietaryPreference.entries.forEach { preference ->
                FilterChip(
                    selected = filters.dietaryPreferences.contains(preference),
                    onClick = {
                        val updated = if (filters.dietaryPreferences.contains(preference)) {
                            filters.dietaryPreferences - preference
                        } else {
                            filters.dietaryPreferences + preference
                        }
                        onFiltersChange(filters.copy(dietaryPreferences = updated))
                    },
                    label = { Text(preference.displayName) }
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Freshness filter
        Text(
            text = "Posted Within",
            style = MaterialTheme.typography.titleSmall
        )
        Spacer(modifier = Modifier.height(8.dp))
        FlowRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            listOf(null to "Any", 1 to "1 hour", 6 to "6 hours", 24 to "24 hours", 72 to "3 days").forEach { (hours, label) ->
                FilterChip(
                    selected = filters.freshnessHours == hours,
                    onClick = {
                        onFiltersChange(filters.copy(freshnessHours = hours))
                    },
                    label = { Text(label) }
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Save preset
        if (showSaveDialog) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = presetName,
                    onValueChange = { presetName = it },
                    label = { Text("Preset name") },
                    modifier = Modifier.weight(1f),
                    singleLine = true
                )
                Spacer(modifier = Modifier.width(8.dp))
                Button(
                    onClick = {
                        if (presetName.isNotBlank()) {
                            onSavePreset(presetName)
                            presetName = ""
                            showSaveDialog = false
                        }
                    },
                    enabled = presetName.isNotBlank()
                ) {
                    Text("Save")
                }
            }
        } else {
            OutlinedButton(
                onClick = { showSaveDialog = true },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Save as Preset")
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Apply button
        Button(
            onClick = onApply,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Apply Filters")
        }

        Spacer(modifier = Modifier.height(32.dp))
    }
}
