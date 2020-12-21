dir.create(Sys.getenv("R_LIBS_USER"), recursive = TRUE)  # create personal library
.libPaths(Sys.getenv("R_LIBS_USER"))  # add to the path
if (!require('ggplot2')) install.packages('ggplot2', lib = Sys.getenv("R_LIBS_USER"), repos = "https://cloud.r-project.org/"); library('ggplot2')
if (!require('tidyr')) install.packages('tidyr', lib = Sys.getenv("R_LIBS_USER"), repos = "https://cloud.r-project.org/"); library('tidyr')
if (!require('tidyverse')) install.packages('tidyverse', lib = Sys.getenv("R_LIBS_USER"), repos = "https://cloud.r-project.org/"); library('tidyverse')
if (!require('extrafont')) {
    install.packages('extrafont', lib = Sys.getenv("R_LIBS_USER"), repos = "https://cloud.r-project.org/")
    library('extrafont')
    font_import(prompt = FALSE)
    loadfonts()
}
library('ggplot2')
library('tidyr')
library('tidyverse')
library('extrafont')


# Resolve file names
args <- commandArgs(trailingOnly = TRUE)
out.path <- args[1]
out.path <- paste0(out.path, "contact/")

name <- args[2]


# Load contact map
file.name <- paste0(out.path, name, "_contact_map.csv")
if (!file.exists(file.name)) {
    stop(cat("Missing file", file.name))
}

contacts.map <- read.table(file.name,
                           header = TRUE,
                           sep = ";",
                           dec = ".",
)


# Get contacting residues
contact.residues <- select(contacts.map, frame, atom1, atom2)
contact.residues$atom1 <- as.numeric(regmatches(contact.residues$atom1, regexpr("[[:digit:]]+", contact.residues$atom1)))
contact.residues$atom2 <- as.numeric(regmatches(contact.residues$atom2, regexpr("[[:digit:]]+", contact.residues$atom2)))


# Get chain residues length
chain1.first <- min(contact.residues$atom1)
chain1.last <- max(contact.residues$atom1)
chain1.length <- length(chain1.first:chain1.last)

chain2.first <- min(contact.residues$atom2)
chain2.last <- max(contact.residues$atom2)
chain2.length <- length(chain2.first:chain2.last)


# Get chains info
peptide.chain <- ''
if (chain1.length > chain2.length) {

    protein.first <- chain1.first
    protein.last <- chain1.last
    protein.length <- chain1.length

    peptide.first <- chain2.first
    peptide.last <- chain2.last
    peptide.length <- chain2.length

    for (i in sort(unique(contact.residues$atom2))) {
        amino <- strsplit(as.character(contacts.map$atom2[match(i, contact.residues$atom2)]), ' ')[[1]][1]
        peptide.chain <- paste0(peptide.chain, i, "\n", amino, " ")
    }
} else {

    protein.first <- chain2.first
    protein.last <- chain2.last
    protein.length <- chain2.length

    peptide.first <- chain1.first
    peptide.last <- chain1.last
    peptide.length <- chain1.length

    for (i in sort(unique(contact.residues$atom1))) {
        amino <- strsplit(as.character(contacts.map$atom1[match(i, contact.residues$atom1)]), ' ')[[1]][1]
        peptide.chain <- paste0(peptide.chain, i, "\n", amino, " ")
    }
}


# Create matrix for residue contact
contact.all.hits <- data.frame(matrix(0L, nrow = protein.length, ncol = peptide.length))
rownames(contact.all.hits) <- as.character(protein.first:protein.last)
colnames(contact.all.hits) <- as.character(peptide.first:peptide.last)

for (line in seq_len(nrow(contact.residues))) {
    row <- as.character(contact.residues[line, "atom1"])
    col <- as.character(contact.residues[line, "atom2"])

    contact.all.hits[row, col] <- contact.all.hits[row, col] + 1
}


# Transform matrix
contact.all.hits <- contact.all.hits %>%
    as.data.frame() %>%
    rownames_to_column("protein") %>%
    pivot_longer(-protein, names_to = "peptide", values_to = "count") %>%
    mutate(peptide = fct_relevel(peptide, colnames(contact.all.hits)))


# Get subset with matchs
all.subset <- contact.all.hits[!(contact.all.hits$count == 0),]


# Plot all graph
out.name <- paste0(out.path, name, "_contact_map_all.png")

print("Ploting contact map.")
plot <- ggplot(all.subset, aes(peptide, protein, fill = count)) +
    geom_raster() +
    scale_fill_gradient(low = "white", high = "red") +
    scale_y_discrete(breaks = unique(all.subset$protein)[c(FALSE, TRUE)]) +
    scale_x_discrete(breaks = 1:peptide.length, labels = str_split(peptide.chain, " ")) +
    labs(title = "Contact per residue", x = "Chain B", y = "Chain A") +
    theme_minimal() +
    theme(text = element_text(family = "Times New Roman")) +
    theme(plot.title = element_text(size = 36, hjust = 0.5)) +
    theme(axis.title = element_text(size = 24)) +
    theme(axis.text.x = element_text(size = 20), axis.text.y = element_text(size = 12)) +
    theme(panel.grid.major.x = element_blank()) +
    geom_vline(xintercept = seq(1.5, peptide.length - 0.5, 1), lwd = 0.5, colour = "black") +
    labs(fill = "Contacts #")

ggsave(out.name, plot, width = 350, height = 150, units = 'mm', dpi = 320, limitsize = FALSE)


# Resolve step number
frames <- max(contact.residues$frame)
if (frames > 50000) {
    step <- 10000
} else if (frames > 10000) {
    step <- 5000
}else if (frames > 1000) {
    step <- 500
}else {
    step <- 100
}
iter <- frames / step


# Create matrix for residue contact every step
contact.hits <- list()
for (i in 1:iter) {
    print(i)
    value <- i * step

    if (i != 1) {
        step.contact <- subset(contact.residues, frame > (value - step) & frame <= value)
    }
    else {
        step.contact <- subset(contact.residues, frame >= (value - step) & frame <= value)
    }

    step.frame <- data.frame(matrix(0L, nrow = protein.length, ncol = peptide.length))
    rownames(step.frame) <- as.character(protein.first:protein.last)
    colnames(step.frame) <- as.character(peptide.first:peptide.last)

    for (line in seq_len(nrow(step.contact))) {
        row <- as.character(step.contact[line, "atom1"])
        col <- as.character(step.contact[line, "atom2"])

        step.frame[row, col] <- step.frame[row, col] + 1
    }

    contact.hits[[i]] <- step.frame
}


# Transform every matrix
max.range <- c(0, 0)
for (i in seq_along(contact.hits)) {
    contact.hits[[i]] <- contact.hits[[i]] %>%
        as.data.frame() %>%
        rownames_to_column("protein") %>%
        pivot_longer(-protein, names_to = "peptide", values_to = "count") %>%
        mutate(peptide = fct_relevel(peptide, colnames(contact.hits[[i]])))

    # Resolve range for scale maps
    range <- range(contact.hits[[i]]$count)
    if (range[2] > max.range[2]) {
        max.range[2] <- range[2]
    }
}


# Plot graph
for (i in seq_along(contact.hits)) {
    png.name <- paste0("_contact_map_", i - 1, "-", i, ".png")
    out.name <- paste0(out.path, name, png.name)

    plot.title <- paste0("Contact per residue ", (i - 1) * 10, "-", i * 10, "k")

    step.subset <- contact.hits[[i]][contact.hits[[i]]$protein %in% all.subset$protein,]
    step.subset$count[step.subset$count == 0] = NA

    cat("Ploting contact map for step", i)
    plot <- ggplot(step.subset, aes(peptide, protein, fill = count)) +
        geom_raster() +
        scale_fill_gradient(low = "white", high = "red", limits = max.range, na.value = "transparent") +
        scale_y_discrete(breaks = unique(all.subset$protein)[c(FALSE, TRUE)]) +
        scale_x_discrete(breaks = 1:peptide.length, labels = str_split(peptide.chain, " ")) +
        labs(title = plot.title, x = "Chain B", y = "Chain A") +
        theme_minimal() +
        theme(text = element_text(family = "Times New Roman")) +
        theme(plot.title = element_text(size = 36, hjust = 0.5)) +
        theme(axis.title = element_text(size = 24)) +
        theme(axis.text.x = element_text(size = 20), axis.text.y = element_text(size = 12)) +
        theme(panel.grid.major.x = element_blank()) +
        geom_vline(xintercept = seq(1.5, peptide.length - 0.5, 1), lwd = 0.5, colour = "black") +
        labs(fill = "Contacts #")

    ggsave(out.name, plot, width = 350, height = 150, units = 'mm', dpi = 320, limitsize = FALSE)
}
print("Done")
