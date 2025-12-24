-- https://github.com/sphamba/smear-cursor.nvim

return {
	"sphamba/smear-cursor.nvim",
	event = "UIEnter",
	opts = {
		-- Smear cursor when switching buffers or windows.
		smear_between_buffers = true,

		-- Smear cursor when moving within line or to neighbor lines.
		-- Use `min_horizontal_distance_smear` and `min_vertical_distance_smear` for finer control
		smear_between_neighbor_lines = true,

		-- Draw the smear in buffer space instead of screen space when scrolling
		scroll_buffer_space = true,

		-- Set to `true` if your font supports legacy computing symbols (block unicode symbols).
		-- Smears and particles will look a lot less blocky.
		legacy_computing_symbols_support = true,

		-- Smear cursor in insert mode.
		-- See also `vertical_bar_cursor_insert_mode` and `distance_stop_animating_vertical_bar`.
		smear_insert_mode = true,
		cursor_color = "#ff4000",
		particles_enabled = true,
		stiffness = 0.5,
		trailing_stiffness = 0.2,
		trailing_exponent = 5,
		damping = 0.6,
		gradient_exponent = 0,
		gamma = 1,
		never_draw_over_target = true, -- if you want to actually see under the cursor
		hide_target_hack = true, -- same
		particle_spread = 1,
		particles_per_second = 500,
		particles_per_length = 50,
		particle_max_lifetime = 800,
		particle_max_initial_velocity = 20,
		particle_velocity_from_cursor = 0.5,
		particle_damping = 0.15,
		particle_gravity = -50,
		min_distance_emit_particles = 0,
	},
}
