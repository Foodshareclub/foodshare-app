package com.foodshare.features.profile.presentation

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.material.icons.filled.Mail
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.foodshare.core.invitation.SentInvite
import com.foodshare.core.validation.ValidationBridge
import com.foodshare.features.profile.presentation.components.InviteForm
import com.foodshare.features.profile.presentation.components.InviteHistoryList
import com.foodshare.features.profile.presentation.components.InviteReferralCard
import com.foodshare.ui.design.components.buttons.GlassButton
import com.foodshare.ui.design.components.buttons.GlassButtonStyle
import com.foodshare.ui.design.components.cards.GlassCard
import com.foodshare.ui.design.components.inputs.GlassTextArea
import com.foodshare.ui.design.components.inputs.GlassTextField
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * Invite screen for sharing referral links and sending direct invitations.
 *
 * Features:
 * - Referral link display with copy-to-clipboard button
 * - Share via native Android share sheet
 * - Email input for direct invitations with validation
 * - Optional personal message field
 * - History of previously sent invitations with status
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InviteScreen(
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: InviteViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Invite Friends",
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.White
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent
                )
            )
        },
        containerColor = Color.Transparent,
        modifier = modifier.background(brush = LiquidGlassGradients.darkAuth)
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Spacing.md)
        ) {
            Spacer(Modifier.height(Spacing.sm))

            // Referral Link Section
            InviteReferralCard(
                referralLink = uiState.referralLink,
                shareText = uiState.shareText,
                onCopyLink = { copyToClipboard(context, uiState.referralLink) },
                onShare = { shareReferralLink(context, uiState.shareText) }
            )

            Spacer(Modifier.height(Spacing.md))

            // Direct Invitation Section
            InviteForm(
                email = uiState.email,
                emailError = uiState.emailError,
                message = uiState.message,
                messageError = uiState.messageError,
                successMessage = uiState.successMessage,
                error = uiState.error,
                isSending = uiState.isSending,
                canSend = uiState.canSend,
                onEmailChange = { viewModel.updateEmail(it) },
                onMessageChange = { viewModel.updateMessage(it) },
                onSend = { viewModel.sendInvitation() }
            )

            Spacer(Modifier.height(Spacing.md))

            // Invitation History Section
            if (uiState.invitesSent.isNotEmpty()) {
                InviteHistoryList(invites = uiState.invitesSent)
            } else if (uiState.isLoading) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(Spacing.lg),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(
                        color = LiquidGlassColors.brandTeal,
                        modifier = Modifier.size(24.dp),
                        strokeWidth = 2.dp
                    )
                }
            }

            Spacer(Modifier.height(Spacing.xxl))
        }
    }
}

/**
 * Copy text to the system clipboard and show a Toast confirmation.
 */
private fun copyToClipboard(context: Context, text: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    val clip = ClipData.newPlainText("FoodShare Referral Link", text)
    clipboard.setPrimaryClip(clip)
    Toast.makeText(context, "Link copied to clipboard", Toast.LENGTH_SHORT).show()
}

/**
 * Open the native Android share sheet with the given share text.
 */
private fun shareReferralLink(context: Context, shareText: String) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, shareText)
        putExtra(Intent.EXTRA_SUBJECT, "Join FoodShare!")
    }
    val chooser = Intent.createChooser(intent, "Share via")
    chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    context.startActivity(chooser)
}
